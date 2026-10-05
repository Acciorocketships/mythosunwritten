// Mirror of LandformFeatures.gd (the parts height_m reaches: draws, basin
// yielding, shapes, links and sample).
using System;
using System.Collections.Generic;
using static Story.Native.GdMath;

namespace Story.Native
{
    internal sealed class Feature
    {
        public FKind Kind;
        public V2 Pos;
        public double[] Q = Array.Empty<double>();
        public double[]? Blob;
        public double Radius;
        public long Cx, Cz;
        public double Rot;
        public long Salt;
    }

    internal sealed class Link
    {
        public V2 Pos, A, B;
        public double Radius, Ha, Hb, Wa, Wb, Sag, Amp;
        public bool Raise, Bench;
    }

    /// Memo values must be reference types; these wrap "no feature" and lists.
    internal sealed class FeatureBox { public Feature? F; }
    internal sealed class CellList { public long[] Cells = Array.Empty<long>(); }
    internal sealed class LinkList { public Link[] Links = Array.Empty<Link>(); }

    internal sealed partial class SeedField
    {
        readonly Memo<FeatureBox> _fDraw = new(1 << 16);
        readonly Memo<FeatureBox> _fMain = new(1 << 16);
        readonly Memo<CellList> _fChosen = new(1 << 16);
        readonly Memo<LinkList> _fLinks = new(1 << 16);

        double FHash(long cx, long cz, long salt) => CellHash01(Seed + salt, cx, cz);
        static double Hs(long salt, long i, long k) => CellHash01(salt + k, i, 0);

        public double Grain(V2 p) => TAU * VNoise01(p.Rotated(0.7), Seed + 1620, 4000.0);

        Feature? FDraw(long cx, long cz)
        {
            long key = Memo<FeatureBox>.Key(cx, cz);
            if (_fDraw.TryGet(key, out var cached)) return cached.F;
            return _fDraw.Store(key, new FeatureBox { F = FDrawRaw(cx, cz) }).F;
        }

        Feature? FDrawRaw(long cx, long cz)
        {
            V2 pos = (new V2((float)cx, (float)cz) + V2.D(0.2 + 0.6 * FHash(cx, cz, 1601),
                0.2 + 0.6 * FHash(cx, cz, 1602))) * T.F_CELL;
            Region region = RegionAt(pos);
            FeatureTable table = T.Features[region.Arch];
            if (FHash(cx, cz, 1603) >= table.Density) return null;
            if (table.Kinds.Length == 0) return null;
            double u = FHash(cx, cz, 1604);
            FKind kind = table.Kinds[table.Kinds.Length - 1];
            for (int i = 0; i < table.Kinds.Length; i++)
            {
                u -= table.KindWeights[i];
                if (u < 0.0)
                {
                    kind = table.Kinds[i];
                    break;
                }
            }
            ParamSpec[] spec = T.FeatureParams[(int)kind] ?? Array.Empty<ParamSpec>();
            double[] q = Draw(cx, cz, 1610, spec, 1.0);
            double scale = Lerp(table.ScaleLo, table.ScaleHi, Math.Pow(FHash(cx, cz, 1605), T.F_HEIGHT_SKEW));
            foreach (var ps in spec)
                if (ps.IsSt) q[ps.Id] = q[ps.Id] * scale;
            double radius = FFootprintRadius(kind, q);
            if (pos.Length() - radius < T.F_SPAWN_CLEAR_M) return null;
            long salt = (long)(FHash(cx, cz, 1607) * 1000000.0);
            double[]? blob = null;
            if (kind == FKind.Hill || kind == FKind.Mesa || kind == FKind.Basin) blob = BlobComponents(q, salt);
            double rot = Grain(pos) + (FHash(cx, cz, 1606) - 0.5) * 0.7;
            return new Feature { Kind = kind, Pos = pos, Q = q, Blob = blob, Radius = radius, Cx = cx, Cz = cz, Rot = rot, Salt = salt };
        }

        Feature? FMain(long cx, long cz)
        {
            long key = Memo<FeatureBox>.Key(cx, cz);
            if (_fMain.TryGet(key, out var cached)) return cached.F;
            return _fMain.Store(key, new FeatureBox { F = FCompute(cx, cz) }).F;
        }

        Feature? FCompute(long cx, long cz)
        {
            Feature? f = FDraw(cx, cz);
            if (f == null || f.Kind != FKind.Basin) return f;
            for (int dz = -2; dz < 3; dz++)
                for (int dx = -2; dx < 3; dx++)
                {
                    if (dx == 0 && dz == 0) continue;
                    Feature? g = FDraw((int)(cx + dx), (int)(cz + dz));
                    if (g != null && T.Raised[(int)g.Kind] && f.Pos.DistanceTo(g.Pos) < 0.5 * (f.Radius + g.Radius))
                        return null;
                }
            return f;
        }

        V2 FeatureSample(V2 p, bool detail)
        {
            long cx = (int)Floori(p.X / T.F_CELL), cz = (int)Floori(p.Y / T.F_CELL);
            double raise = 0.0, cut = 0.0;
            for (int dz = -1; dz < 2; dz++)
                for (int dx = -1; dx < 2; dx++)
                {
                    long x = (int)(cx + dx), z = (int)(cz + dz);
                    Feature? f = FMain(x, z);
                    if (f != null && p.DistanceTo(f.Pos) < f.Radius)
                    {
                        V2 v = FShape(f.Kind, f.Q, f.Blob, (p - f.Pos).Rotated(-f.Rot), f.Salt, detail);
                        raise = Union(raise, v.X);
                        cut = Union(cut, v.Y);
                    }
                    foreach (Link link in LinksOwned(x, z))
                    {
                        if (p.DistanceTo(link.Pos) < link.Radius)
                        {
                            double h = LinkShape(link, p, detail);
                            if (link.Raise) raise = Union(raise, h);
                            else cut = Union(cut, h);
                        }
                    }
                }
            return V2.D(raise, cut);
        }

        static double Net(V2 v) => v.X - v.Y * (1.0 - 0.75 * Smoothstep(0.0, 12.0, v.X));

        double Union(double a, double b)
        {
            if (a <= 0.0) return Max(b, 0.0);
            if (b <= 0.0) return a;
            return Math.Pow(Math.Pow(a, T.F_NORM) + Math.Pow(b, T.F_NORM), 1.0 / T.F_NORM);
        }

        static double FFootprintRadius(FKind kind, double[] q)
        {
            switch (kind)
            {
                case FKind.Hill: case FKind.PeakCluster: case FKind.ButteGroup: case FKind.TowerCluster: case FKind.Basin:
                    return q[P.radius_m];
                case FKind.Ridge: case FKind.Valley:
                    return q[P.half_length_m];
                case FKind.Mesa:
                    return q[P.radius_m] + 64.0;
                case FKind.Escarpment:
                    return Max(q[P.half_length_m], q[P.back_m] + 24.0);
                case FKind.Amphitheatre:
                    return q[P.radius_m] * 1.4;
            }
            return 0.0;
        }

        static double FEnvelope(double r, double radius) => 1.0 - Smoothstep(radius - Min(60.0, 0.3 * radius), radius, r);

        static double Lobes(V2 local, long salt)
        {
            V2 dir = local.LengthSquared() > 1e-6 ? local.Normalized() : new V2(1f, 0f);
            return VNoise01(dir * 0.65, salt, 1.0);
        }

        double[] BlobComponents(double[] q, long salt)
        {
            double radius = q[P.radius_m];
            double satLo = 0.7, satHi = 0.9;
            if (P.Has(q, P.peaks) || P.Has(q, P.spread))
            {
                satLo = 0.4;
                satHi = 0.7;
            }
            var outL = new List<double>(18);
            long satellites = (long)(Hs(salt, 0, 46) * 2.999);
            double coreA = radius * (0.6 + 0.18 * Hs(salt, 0, 41));
            double coreAspect = satellites == 0 ? (0.5 + 0.3 * Hs(salt, 0, 44)) : (0.5 + 0.45 * Hs(salt, 0, 44));
            if (P.Has(q, P.depth_st)) coreAspect = 0.35 + 0.25 * Hs(salt, 0, 44);
            outL.Add((Hs(salt, 0, 42) - 0.5) * 0.16 * radius);
            outL.Add((Hs(salt, 0, 43) - 0.5) * 0.16 * radius);
            outL.Add(coreA);
            outL.Add(coreA * coreAspect);
            outL.Add((Hs(salt, 0, 45) - 0.5) * 0.6);
            outL.Add(1.0);
            double coreRot = outL[4];
            double firstEnd = Hs(salt, 1, 48) < 0.5 ? 1.0 : -1.0;
            for (long i = 1; i < satellites + 1; i++)
            {
                double end = (i == 1 ? firstEnd : -firstEnd) * (0.5 + 0.3 * Hs(salt, i, 47)) * coreA;
                V2 at = V2.D(outL[0], outL[1]) + V2.D(end, (Hs(salt, i, 52) - 0.5) * 0.5 * coreA * coreAspect).Rotated(coreRot);
                double dist = at.Length();
                double a = Max(0.1 * radius, Min(radius * (0.28 + 0.22 * Hs(salt, i, 49)), 0.92 * radius - dist));
                outL.Add(at.X);
                outL.Add(at.Y);
                outL.Add(a);
                outL.Add(a * (0.4 + 0.5 * Hs(salt, i, 50)));
                outL.Add(Hs(salt, i, 53) * TAU);
                outL.Add(Lerp(satLo, satHi, Hs(salt, i, 54)));
            }
            return outL.ToArray();
        }

        static V2 BlobWarp(double[] q, V2 local, long salt)
        {
            double wl = 0.4 * q[P.radius_m];
            return local + V2.D(VNoise(local, salt + 61, wl), VNoise(local, salt + 62, wl)) * 0.18 * q[P.radius_m];
        }

        static double ComponentT(double[] c, int k, V2 w)
        {
            int i = k * 6;
            V2 d = (w - V2.D(c[i], c[i + 1])).Rotated(-c[i + 4]);
            return V2.D(d.X / c[i + 2], d.Y / c[i + 3]).Length();
        }

        double[] Components(double[] q, double[]? blob, long salt) => blob ?? BlobComponents(q, salt);

        double BlobHeight(double[] q, double[]? blob, V2 local, long salt, bool plateau, bool detail)
        {
            double[] c = Components(q, blob, salt);
            V2 w = BlobWarp(q, local, salt);
            double best = 0.0;
            int n = c.Length / 6;
            for (int k = 0; k < n; k++)
            {
                double t = ComponentT(c, k, w);
                if (t >= 1.0) continue;
                double v;
                if (!plateau)
                {
                    v = Math.Pow(1.0 - t * t, 2.0);
                }
                else
                {
                    double b = c[k * 6 + 3];
                    double rim = detail ? 6.0 / b : 0.6;
                    v = 1.0 - Smoothstep(1.0 - rim, 1.0, t);
                }
                best = Max(best, v * c[k * 6 + 5]);
            }
            return best;
        }

        double BlobT(double[] q, double[]? blob, V2 local, long salt)
        {
            double[] c = Components(q, blob, salt);
            V2 w = BlobWarp(q, local, salt);
            double best = INF;
            int n = c.Length / 6;
            for (int k = 0; k < n; k++) best = Min(best, ComponentT(c, k, w));
            return best;
        }

        static double Tilt(double[] q, V2 local, long salt)
        {
            V2 dir = V2.FromAngle(Hs(salt, 0, 55) * TAU);
            double amount = 0.3 * Hs(salt, 0, 56);
            return 1.0 + amount * Clamp(local.Dot(dir) / q[P.radius_m], -1.0, 1.0);
        }

        V2 FShape(FKind kind, double[] q, double[]? blob, V2 local, long salt, bool detail)
        {
            double ST = T.STOREY;
            double r = local.Length();
            double raise = 0.0, cut = 0.0;
            switch (kind)
            {
                case FKind.Hill:
                    raise = q[P.height_st] * ST * BlobHeight(q, blob, local, salt, false, detail) * Tilt(q, local, salt);
                    break;
                case FKind.PeakCluster:
                    raise = Cluster(q, local, salt, detail);
                    break;
                case FKind.Ridge:
                    raise = FRidge(q, local, salt, detail);
                    break;
                case FKind.Mesa:
                    raise = Mesa(q, blob, local, salt, detail);
                    break;
                case FKind.ButteGroup:
                    raise = Scatter(q, local, salt, q[P.buttes], q[P.butte_radius_m], 0.6, true, detail);
                    break;
                case FKind.TowerCluster:
                    raise = Scatter(q, local, salt, q[P.towers], q[P.tower_radius_m], 0.55, false, detail);
                    break;
                case FKind.Basin:
                {
                    double t = BlobT(q, blob, local, salt);
                    double depth = q[P.depth_st] * ST;
                    cut = depth * (1.0 - Smoothstep(q[P.floor], 0.95, t)) * Tilt(q, local, salt);
                    V2 lip = V2.FromAngle(Hs(salt, 0, 59) * TAU);
                    double side = local.LengthSquared() > 1.0 ? Smoothstep(-0.2, 0.8, local.Normalized().Dot(lip)) : 0.0;
                    raise = q[P.rim_st] * ST * Math.Exp(-Math.Pow((t - 1.0) / 0.12, 2.0)) * side;
                    if (q[P.island] >= 0.7)
                    {
                        double ir = q[P.island_radius] * q[P.floor] * q[P.radius_m];
                        V2 off = V2.D((0.3 + 0.25 * Hs(salt, 0, 58)) * (Hs(salt, 0, 57) < 0.5 ? 1.0 : -1.0) * q[P.floor] * q[P.radius_m], 0.0);
                        V2 e = (local - off).Rotated(-Hs(salt, 0, 51) * TAU);
                        double ti = V2.D(e.X / ir, e.Y / (ir * (0.55 + 0.4 * Hs(salt, 0, 52)))).Length();
                        double profile = detail && salt % 2 == 0
                            ? 1.0 - Smoothstep(0.85, 1.0, ti)
                            : Math.Pow(Max(0.0, 1.0 - ti * ti), 1.5);
                        raise = Max(raise, (depth + q[P.island_st] * ST) * profile);
                    }
                    break;
                }
                case FKind.Valley:
                {
                    double half = q[P.half_length_m];
                    double shift = 0.7 * q[P.floor_half_m] * Math.Sin(local.X / half * PI);
                    double along = 1.0 - Smoothstep(0.65 * half, half, Math.Abs((double)local.X));
                    double across = 1.0 - Smoothstep(q[P.floor_half_m], q[P.floor_half_m] + q[P.side_m], Math.Abs(local.Y - shift));
                    cut = q[P.depth_st] * ST * along * across;
                    break;
                }
                case FKind.Escarpment:
                {
                    double half = q[P.half_length_m];
                    double wob = q[P.face_m] * 1.5 * Math.Sin(local.X / half * PI * 1.5 + (double)(salt % 7));
                    double face = q[P.face_m] * (detail ? 1.0 : 6.0);
                    double step = Smoothstep(-face * 0.5, face * 0.5, local.Y + wob);
                    double back = 1.0 - Smoothstep(q[P.back_m] * 0.6, q[P.back_m], local.Y);
                    double along = 1.0 - Smoothstep(0.7 * half, half, Math.Abs((double)local.X));
                    raise = q[P.rise_st] * ST * step * back * along;
                    break;
                }
                case FKind.Amphitheatre:
                {
                    V2 e = V2.D(local.X * 1.35, local.Y);
                    double re = e.Length();
                    double radius = q[P.radius_m] * (0.8 + 0.4 * Lobes(local, salt));
                    double ring = Math.Exp(-Math.Pow((re - radius) / (q[P.thickness] * q[P.radius_m]), 2.0));
                    double mouth = Smoothstep(-0.55, 0.05, local.X / Max(r, 1.0));
                    raise = q[P.wall_st] * ST * ring * (1.0 - 0.9 * mouth);
                    break;
                }
            }
            double env = FEnvelope(r, FFootprintRadius(kind, q));
            return V2.D(Max(raise, 0.0) * env, Max(cut, 0.0) * env);
        }

        static double Round01(double t, double e) => (Math.Sqrt(t * t + e * e) - e) / (Math.Sqrt(1.0 + e * e) - e);

        static V2[] ClusterSummits(double[] q, long salt)
        {
            long n = ClampI(Roundi(q[P.peaks]), 2, 4);
            double b = Hs(salt, 0, 11) * TAU;
            var outS = new V2[n];
            for (long i = 0; i < n; i++)
            {
                double angle = b + i * TAU / n + (Hs(salt, i, 12) - 0.5) * 0.5;
                outS[i] = V2.FromAngle(angle) * q[P.spread] * q[P.radius_m];
            }
            return outS;
        }

        double Cluster(double[] q, V2 local, long salt, bool detail)
        {
            double height = q[P.height_st] * T.STOREY;
            V2[] summits = ClusterSummits(q, salt);
            int n = summits.Length;
            Span<double> heights = stackalloc double[n];
            for (int i = 0; i < n; i++) heights[i] = height * (i == 0 ? 1.0 : 0.75 + 0.25 * Hs(salt, i, 13));
            double coneR = 0.55 * q[P.radius_m];
            double best = 0.0;
            for (int i = 0; i < n; i++)
            {
                double d = local.DistanceTo(summits[i]);
                if (d < coneR)
                {
                    double t = detail ? d / coneR : Round01(d / coneR, 0.25);
                    best = Max(best, heights[i] * Math.Pow(1.0 - t, 1.5));
                }
            }
            double width = 0.22 * q[P.radius_m];
            int pairs = n > 2 ? n : 1;
            for (int i = 0; i < pairs; i++)
            {
                V2 a = summits[i];
                V2 b = summits[(i + 1) % n];
                V2 ab = b - a;
                double t = Clamp((double)(local - a).Dot(ab) / (double)ab.LengthSquared(), 0.0, 1.0);
                double d = local.DistanceTo(a + ab * t);
                if (d < width)
                {
                    double crest = Lerp(heights[i], heights[(i + 1) % n], t) * (1.0 - (1.0 - q[P.saddle]) * Math.Sin(PI * t));
                    double w = detail ? d / width : Round01(d / width, 0.3);
                    best = Max(best, crest * Math.Pow(1.0 - w, 1.4));
                }
            }
            double apron = 0.25 * height * Math.Pow(Max(0.0, 1.0 - local.Length() / q[P.radius_m]), 2.0);
            return Max(best, apron);
        }

        double FRidge(double[] q, V2 local, long salt, bool detail)
        {
            double half = q[P.half_length_m];
            double u = local.X;
            double v = local.Y + (salt % 2 == 0 ? 1.0 : -1.0) * 0.6 * q[P.half_width_m] * Math.Sin(u / half * PI * 1.3);
            double along = 1.0 - Smoothstep(0.7 * half, half, Math.Abs(u));
            double passU = q[P.pass_at] * half;
            double gap = 1.0 - q[P.pass_depth] * Math.Exp(-Math.Pow((u - passU) / (0.18 * half), 2.0));
            double crest = q[P.height_st] * T.STOREY * along * gap * (0.85 + 0.15 * Math.Cos(u / half * PI));
            double t = Min(Math.Abs(v) / q[P.half_width_m], 1.0);
            double across = 1.0 - (detail ? t : Round01(t, 0.3));
            return crest * Math.Pow(across, 1.3);
        }

        double Mesa(double[] q, double[]? blob, V2 local, long salt, bool detail)
        {
            double ST = T.STOREY;
            double height = q[P.height_st] * ST;
            double top = height * BlobHeight(q, blob, local, salt, true, detail);
            double t = BlobT(q, blob, local, salt);
            double apron = q[P.apron] * height * (1.0 - Smoothstep(1.0, 1.0 + 40.0 / (0.6 * q[P.radius_m]), t));
            double h = Max(top, apron);
            if (q[P.tier] >= 0.5)
            {
                double[] c = Components(q, blob, salt);
                V2 d = (local - V2.D(c[0], c[1])).Rotated(-c[4]) - V2.D((salt % 3 == 0 ? 0.3 : -0.3) * c[2], 0.0);
                double tt = V2.D(d.X / (0.5 * c[2]), d.Y / (0.5 * c[3])).Length();
                double rim = detail ? 5.0 : 0.8 * 0.5 * c[3];
                h += q[P.tier_st] * ST * (1.0 - Smoothstep(1.0 - rim / (0.5 * c[3]), 1.0, tt));
            }
            return h;
        }

        double Scatter(double[] q, V2 local, long salt, double count, double eachR, double reach, bool flat, bool detail)
        {
            double height = q[P.height_st] * T.STOREY;
            double lng = reach * q[P.radius_m];
            V2 e0 = local / V2.D(lng + eachR, 0.35 * lng + 1.2 * eachR);
            e0 = e0 + V2.D(VNoise(local, salt + 63, 0.5 * lng), VNoise(local, salt + 64, 0.5 * lng)) * 0.15;
            double benchT = e0.Length();
            double benchLo = flat ? (detail ? 0.7 : 0.4) : 0.0;
            double best = q[P.plinth] * height * (1.0 - Smoothstep(benchLo, 1.0, benchT));
            long cnt = ClampI(Roundi(count), 1, 8);
            for (long i = 0; i < cnt; i++)
            {
                V2 at = V2.D((Hs(salt, i, 21) - 0.5) * 2.0 * lng, (Hs(salt, i, 22) - 0.5) * 0.6 * lng);
                double radius = eachR * (0.75 + 0.5 * Hs(salt, i, 23));
                double hi = height * (0.7 + 0.3 * Hs(salt, i, 24));
                V2 e = (local - at).Rotated(-Hs(salt, i, 25) * TAU);
                double t = V2.D(e.X, e.Y / (0.55 + 0.45 * Hs(salt, i, 26))).Length() / radius;
                double h;
                if (!detail)
                {
                    h = hi * Math.Pow(Max(0.0, 1.0 - t * t), 2.0);
                }
                else if (flat)
                {
                    double top = hi * (1.0 - Smoothstep(1.0 - 5.0 / radius, 1.0, t));
                    double apron = 0.2 * hi * (1.0 - Smoothstep(1.0, 1.0 + 20.0 / radius, t));
                    h = Max(top, apron);
                }
                else
                {
                    h = hi * (1.0 - Smoothstep(0.45, 1.0, t));
                }
                best = Max(best, h);
            }
            return best;
        }

        // ---------------- links ----------------
        int LinkClass(FKind k) => T.Raised[(int)k] ? 1 : (T.Hollow[(int)k] ? -1 : 0);

        static V2 Endpoint(Feature f, V2 toward)
        {
            double[] q = f.Q;
            V2 dir = V2.FromAngle(f.Rot);
            switch (f.Kind)
            {
                case FKind.Ridge:
                {
                    double half = q[P.half_length_m];
                    double u = Clamp((toward - f.Pos).Dot(dir), -0.6 * half, 0.6 * half);
                    double v = -(f.Salt % 2 == 0 ? 1.0 : -1.0) * 0.6 * q[P.half_width_m] * Math.Sin(u / half * PI * 1.3);
                    return f.Pos + V2.D(u, v).Rotated(f.Rot);
                }
                case FKind.Valley:
                {
                    double half = q[P.half_length_m];
                    double u = Clamp((toward - f.Pos).Dot(dir), -0.55 * half, 0.55 * half);
                    return f.Pos + V2.D(u, 0.7 * q[P.floor_half_m] * Math.Sin(u / half * PI)).Rotated(f.Rot);
                }
            }
            return f.Pos + (toward - f.Pos).Normalized() * 0.15 * q[P.radius_m];
        }

        double Top(Feature f)
        {
            double[] q = f.Q;
            double ST = T.STOREY;
            if (T.Hollow[(int)f.Kind]) return q[P.depth_st] * ST;
            if (f.Kind == FKind.ButteGroup || f.Kind == FKind.TowerCluster) return q[P.plinth] * q[P.height_st] * ST;
            return q[P.height_st] * ST;
        }

        static double LinkWidth(Feature f)
        {
            double[] q = f.Q;
            switch (f.Kind)
            {
                case FKind.Ridge: return 0.9 * q[P.half_width_m];
                case FKind.Valley: return q[P.floor_half_m] + 0.6 * q[P.side_m];
                case FKind.Basin: return Clamp(0.2 * q[P.radius_m], 35.0, 80.0);
            }
            return Clamp(0.28 * q[P.radius_m], 50.0, 100.0);
        }

        Link? LinkGeometry(Feature fa, Feature fb)
        {
            if (fb.Cx < fa.Cx || (fb.Cx == fa.Cx && fb.Cz < fa.Cz))
            {
                Feature t = fa;
                fa = fb;
                fb = t;
            }
            long cax = fa.Cx, caz = fa.Cz, cbx = fb.Cx, cbz = fb.Cz;
            V2 a = Endpoint(fa, fb.Pos);
            V2 b = Endpoint(fb, fa.Pos);
            double length = a.DistanceTo(b);
            if (length < 24.0) return null;
            long salt;
            unchecked { salt = (long)(CellHash01(Seed + 1630 + cbx * 7919 + cbz * 104729, cax, caz) * 1000000.0); }
            double wa = LinkWidth(fa);
            double wb = LinkWidth(fb);
            double amp = (Hs(salt, 0, 3) - 0.5) * 0.3 * length;
            double radius = 0.5 * length + Max(wa, wb) + Math.Abs(amp);
            if (radius > T.F_LINK_MAX_RADIUS) return null;
            bool raised = LinkClass(fa.Kind) > 0;
            bool bench = raised && T.Benched[(int)fa.Kind] && T.Benched[(int)fb.Kind];
            double frac = 0.45 + 0.2 * Hs(salt, 0, 1);
            double ha = frac * Top(fa);
            double hb = frac * Top(fb);
            if (bench)
            {
                ha = 0.55 * Min(Top(fa), Top(fb));
                hb = ha;
            }
            return new Link
            {
                Pos = (a + b) * 0.5, A = a, B = b, Radius = radius, Raise = raised, Bench = bench,
                Ha = ha, Hb = hb, Wa = wa, Wb = wb, Sag = 0.15 + 0.25 * Hs(salt, 0, 2), Amp = amp,
            };
        }

        long[] Chosen(long cx, long cz)
        {
            long key = Memo<CellList>.Key(cx, cz);
            if (_fChosen.TryGet(key, out var cached)) return cached.Cells;
            return _fChosen.Store(key, new CellList { Cells = ChosenRaw(cx, cz) }).Cells;
        }

        long[] ChosenRaw(long cx, long cz)
        {
            Feature? f = FMain(cx, cz);
            if (f == null || LinkClass(f.Kind) == 0) return Array.Empty<long>();
            double g = Grain(f.Pos);
            var options = new List<(double score, int index, long x, long z)>();
            for (int dz = -1; dz < 2; dz++)
                for (int dx = -1; dx < 2; dx++)
                {
                    long ox = (int)(cx + dx), oz = (int)(cz + dz);
                    Feature? o = FMain(ox, oz);
                    if ((ox == cx && oz == cz) || o == null || LinkClass(o.Kind) != LinkClass(f.Kind)) continue;
                    if (LinkGeometry(f, o) == null) continue;
                    V2 to = o.Pos - f.Pos;
                    options.Add(((double)to.Length() * (1.0 + 0.7 * Math.Abs(Math.Sin(to.Angle() - g))), options.Count, ox, oz));
                }
            // Stable; GDScript's sort_custom can only differ on exact score ties.
            options.Sort((x, y) => x.score < y.score ? -1 : (y.score < x.score ? 1 : x.index.CompareTo(y.index)));
            var sorted = options;
            var outC = new List<long>(2);
            if (sorted.Count > 0 && FHash(cx, cz, 1631) < T.F_LINK_FIRST) outC.Add(Memo<CellList>.Key(sorted[0].x, sorted[0].z));
            if (sorted.Count > 1 && FHash(cx, cz, 1632) < T.F_LINK_SECOND) outC.Add(Memo<CellList>.Key(sorted[1].x, sorted[1].z));
            return outC.ToArray();
        }

        static long KeyX(long key) => key >> 32;
        static long KeyZ(long key) => (int)(key & 0xFFFFFFFFL);

        Link[] LinksOwned(long cx, long cz)
        {
            long key = Memo<LinkList>.Key(cx, cz);
            if (_fLinks.TryGet(key, out var cached)) return cached.Links;
            return _fLinks.Store(key, new LinkList { Links = LinksOwnedRaw(cx, cz) }).Links;
        }

        Link[] LinksOwnedRaw(long cx, long cz)
        {
            var outL = new List<Link>();
            var seen = new HashSet<(long, long, long, long)>();
            for (int dz = -1; dz < 2; dz++)
                for (int dx = -1; dx < 2; dx++)
                {
                    long ax = (int)(cx + dx), az = (int)(cz + dz);
                    foreach (long cb in Chosen(ax, az))
                    {
                        long bx = KeyX(cb), bz = KeyZ(cb);
                        var k = (ax, az, bx, bz);
                        if (ax > bx || (ax == bx && az > bz)) k = (bx, bz, ax, az);
                        if (!seen.Add(k)) continue;
                        Feature? fa = FMain(ax, az), fb = FMain(bx, bz);
                        if (fa == null || fb == null) continue;
                        Link? link = LinkGeometry(fa, fb);
                        if (link != null && (int)Floori(link.Pos.X / T.F_CELL) == cx && (int)Floori(link.Pos.Y / T.F_CELL) == cz)
                            outL.Add(link);
                    }
                }
            return outL.ToArray();
        }

        static double LinkShape(Link link, V2 p, bool detail)
        {
            V2 ab = link.B - link.A;
            double length = ab.Length();
            V2 dir = ab / length;
            V2 rel = p - link.A;
            double u = rel.Dot(dir);
            double t = Clamp(u / length, 0.0, 1.0);
            double v = rel.Dot(dir.Orthogonal()) - link.Amp * Math.Sin(PI * t);
            double du = u < 0.0 ? -u : Max(0.0, u - length);
            double d = Math.Sqrt(du * du + v * v);
            double w = Lerp(link.Wa, link.Wb, t);
            if (d >= w) return 0.0;
            double x = d / w;
            double level = Lerp(link.Ha, link.Hb, t);
            if (!link.Raise) return level * (1.0 - 0.25 * Math.Sin(PI * t)) * (1.0 - Smoothstep(0.35, 1.0, x));
            if (link.Bench) return level * (1.0 - Smoothstep(detail ? 0.75 : 0.3, 1.0, x));
            return level * (1.0 - link.Sag * Math.Sin(PI * t)) * Math.Pow(1.0 - (detail ? x : Round01(x, 0.3)), 1.3);
        }
    }
}
