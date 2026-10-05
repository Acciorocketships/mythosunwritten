// Mirror of LandformSetpieces.gd.
using System;
using static Story.Native.GdMath;

namespace Story.Native
{
    internal sealed class Setpiece
    {
        public static readonly Setpiece None = new();
        public bool Empty = true;
        public SpKind Kind;
        public V2 Pos;
        public double[] Q = Array.Empty<double>();
        public long Cx, Cz;
        public double Rot, Priority, Radius;
    }

    internal sealed partial class SeedField
    {
        readonly Memo<Setpiece> _spCandidates = new(1 << 15);
        readonly Memo<Setpiece> _spAdmitted = new(1 << 15);

        Setpiece SpCandidate(long cx, long cz)
        {
            long key = Memo<Setpiece>.Key(cx, cz);
            if (_spCandidates.TryGet(key, out var cached)) return cached;
            V2 pos = (new V2((float)cx, (float)cz) + V2.D(
                0.15 + 0.7 * CellHash01(Seed + 1501, cx, cz),
                0.15 + 0.7 * CellHash01(Seed + 1502, cx, cz))) * T.SP_CELL;
            int arch = RegionAt(pos).Arch;
            SpKind[] kinds = T.SetpieceKinds[arch];
            double[] dens = T.SetpieceDensity[arch];
            double u = CellHash01(Seed + 1503, cx, cz);
            int kind = -1;
            for (int i = 0; i < kinds.Length; i++)
            {
                u -= dens[i];
                if (u < 0.0)
                {
                    kind = i;
                    break;
                }
            }
            Setpiece value = Setpiece.None;
            if (kind >= 0)
            {
                SpKind k = kinds[kind];
                double[] q = Draw(cx, cz, 1510, T.SetpieceParams[(int)k] ?? Array.Empty<ParamSpec>(), 1.0);
                var sp = new Setpiece
                {
                    Empty = false, Kind = k, Pos = pos, Q = q, Cx = cx, Cz = cz,
                    Rot = CellHash01(Seed + 1504, cx, cz) * TAU,
                    Priority = CellHash01(Seed + 1505, cx, cz),
                    Radius = SpFootprintRadius(k, q),
                };
                if (!(pos.Length() - sp.Radius < T.SP_SPAWN_CLEAR_M)) value = sp;
            }
            return _spCandidates.Store(key, value);
        }

        static bool SpOutranks(Setpiece a, Setpiece b)
        {
            if (a.Priority != b.Priority) return a.Priority > b.Priority;
            return a.Cx < b.Cx || (a.Cx == b.Cx && a.Cz < b.Cz);
        }

        Setpiece SpAdmitted(long cx, long cz)
        {
            long key = Memo<Setpiece>.Key(cx, cz);
            if (_spAdmitted.TryGet(key, out var cached)) return cached;
            Setpiece c = SpCandidate(cx, cz);
            Setpiece value = c;
            if (!c.Empty)
            {
                for (int dz = -2; dz < 3; dz++)
                    for (int dx = -2; dx < 3; dx++)
                    {
                        if (dx == 0 && dz == 0) continue;
                        Setpiece o = SpCandidate((int)(cx + dx), (int)(cz + dz));
                        if (!o.Empty && SpOutranks(o, c) && c.Pos.DistanceTo(o.Pos) < c.Radius + o.Radius)
                            value = Setpiece.None;
                    }
            }
            return _spAdmitted.Store(key, value);
        }

        V2 SetpieceSample(V2 p)
        {
            long cx = (int)Floori(p.X / T.SP_CELL), cz = (int)Floori(p.Y / T.SP_CELL);
            for (int dz = -1; dz < 2; dz++)
                for (int dx = -1; dx < 2; dx++)
                {
                    Setpiece a = SpAdmitted((int)(cx + dx), (int)(cz + dz));
                    if (a.Empty || p.DistanceTo(a.Pos) >= a.Radius) continue;
                    return SpShape(a.Kind, a.Q, (p - a.Pos).Rotated(-a.Rot), a.Priority * TAU);
                }
            return V2.Zero;
        }

        double SpFootprintRadius(SpKind kind, double[] q)
        {
            double F = T.SP_FEATHER;
            switch (kind)
            {
                case SpKind.Escarpment:
                case SpKind.BigRidge:
                case SpKind.HangingValley:
                    return q[P.length_m] * 0.5 + F * 0.5;
                case SpKind.Cleft:
                    return Max(q[P.length_m] * 0.5, q[P.slot_m] * 0.5 + q[P.shoulder_m] + F) + F * 0.5;
            }
            return 0.0;
        }

        double SpEnvelope(double r, double radius) => 1.0 - Smoothstep(radius - T.SP_FEATHER, radius, r);

        double SpAlong(double u, double half) => 1.0 - Smoothstep(half - 2.0 * T.SP_FEATHER, half, Math.Abs(u));

        V2 SpShape(SpKind kind, double[] q, V2 local, double phase)
        {
            double ST = T.STOREY;
            double F = T.SP_FEATHER;
            double env = SpEnvelope(local.Length(), SpFootprintRadius(kind, q));
            double delta = 0.0, mask = 0.0;
            double lx = local.X, ly = local.Y;
            switch (kind)
            {
                case SpKind.Escarpment:
                {
                    double half = q[P.length_m] * 0.5;
                    double v = ly + Math.Sin(lx / q[P.length_m] * TAU * 1.5 + phase) * q[P.face_m] * 1.5;
                    double step = Smoothstep(-q[P.face_m] * 0.5, q[P.face_m] * 0.5, v);
                    double across = 1.0 - Smoothstep(q[P.back_m] * 0.5, q[P.back_m], Math.Abs(ly));
                    double along = SpAlong(lx, half);
                    delta = (step - 0.5) * q[P.rise_st] * ST * across * along;
                    mask = across * along;
                    break;
                }
                case SpKind.BigRidge:
                {
                    double across = Math.Exp(-Math.Pow(ly / q[P.half_width_m], 2.0));
                    double saddle = 1.0 - q[P.pass_frac] * Math.Exp(-Math.Pow(lx / (0.12 * q[P.length_m]), 2.0));
                    double along = SpAlong(lx, q[P.length_m] * 0.5);
                    delta = q[P.height_st] * ST * across * saddle * along;
                    mask = Smoothstep(0.0, 0.3, across) * along;
                    break;
                }
                case SpKind.Cleft:
                {
                    double a = Math.Abs(ly + Math.Sin(lx / q[P.length_m] * TAU + phase) * q[P.slot_m]);
                    double inner = q[P.slot_m] * 0.5;
                    double outer = inner + q[P.shoulder_m];
                    double shoulders = Smoothstep(inner, inner + 16.0, a) * (1.0 - Smoothstep(outer, outer + F, a));
                    double along = SpAlong(lx, q[P.length_m] * 0.5);
                    delta = q[P.shoulder_st] * ST * shoulders * along;
                    mask = (1.0 - Smoothstep(outer, outer + F, a)) * along;
                    break;
                }
                case SpKind.HangingValley:
                {
                    double half = q[P.length_m] * 0.5;
                    double along = SpAlong(lx, half);
                    double trunk = (1.0 - Smoothstep(q[P.trunk_half_m], q[P.trunk_half_m] + 32.0, Math.Abs(ly))) * along;
                    double trib = (1.0 - Smoothstep(q[P.trib_half_m], q[P.trib_half_m] + 24.0, Math.Abs(lx)))
                        * Smoothstep(q[P.trunk_half_m], q[P.trunk_half_m] + 8.0, ly) * SpAlong(ly, half);
                    double tribDepth = Max(q[P.trunk_st] - q[P.lip_st], 1.0);
                    delta = -q[P.trunk_st] * ST * trunk - tribDepth * ST * trib * (1.0 - trunk);
                    mask = Max(trunk, trib);
                    break;
                }
            }
            return V2.D(delta * env, Clamp(mask, 0.0, 1.0) * env);
        }
    }
}
