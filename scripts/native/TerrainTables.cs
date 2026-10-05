// The live tuning tables of TerrainRegimeCatalog / LandformFeatures / ... as
// handed over by NativeHeightField.gd. Nothing tunable is copied into C#: the
// GDScript side reads the current constants and dictionaries, so a pure tuning
// change keeps parity. Literal numbers written inside GDScript functions are
// mirrored in the C# code itself; the startup parity check catches any drift.
using System;
using System.Collections.Generic;
using Godot;

namespace Story.Native
{
    /// Parameter slots. Every parameter dictionary becomes a double[] indexed by
    /// these ids (NaN = absent, i.e. Dictionary.has() is false).
    internal static class P
    {
        public static readonly string[] Known =
        {
            // archetypes
            "base_level_st", "relief_st", "hummock_wl_m", "ridge_spacing_m", "ridge_st",
            "pass_spacing_m", "pass_depth", "gully_spacing_m", "gully_st", "tread_rise_st",
            "tread_depth_m", "riser_frac", "steps", "valley_half_width_m", "treads", "cell_m",
            "channel_m", "rim_st",
            // set pieces
            "length_m", "rise_st", "face_m", "back_m", "height_st", "half_width_m", "pass_frac",
            "slot_m", "shoulder_st", "shoulder_m", "trunk_half_m", "trunk_st", "trib_half_m", "lip_st",
            // features
            "radius_m", "aspect", "peaks", "saddle", "spread", "half_length_m", "pass_at",
            "wobble", "tier", "tier_st", "apron", "buttes", "butte_radius_m", "plinth", "towers",
            "tower_radius_m", "depth_st", "floor", "island", "island_radius", "island_st",
            "floor_half_m", "side_m", "wall_st", "thickness",
        };

        public const int base_level_st = 0, relief_st = 1, hummock_wl_m = 2, ridge_spacing_m = 3,
            ridge_st = 4, pass_spacing_m = 5, pass_depth = 6, gully_spacing_m = 7, gully_st = 8,
            tread_rise_st = 9, tread_depth_m = 10, riser_frac = 11, steps = 12,
            valley_half_width_m = 13, treads = 14, cell_m = 15, channel_m = 16, rim_st = 17,
            length_m = 18, rise_st = 19, face_m = 20, back_m = 21, height_st = 22,
            half_width_m = 23, pass_frac = 24, slot_m = 25, shoulder_st = 26, shoulder_m = 27,
            trunk_half_m = 28, trunk_st = 29, trib_half_m = 30, lip_st = 31,
            radius_m = 32, aspect = 33, peaks = 34, saddle = 35, spread = 36, half_length_m = 37,
            pass_at = 38, wobble = 39, tier = 40, tier_st = 41, apron = 42, buttes = 43,
            butte_radius_m = 44, plinth = 45, towers = 46, tower_radius_m = 47, depth_st = 48,
            floor = 49, island = 50, island_radius = 51, island_st = 52, floor_half_m = 53,
            side_m = 54, wall_st = 55, thickness = 56;

        public static bool Has(double[] q, int id) => id < q.Length && !double.IsNaN(q[id]);
    }

    /// One parameter of a TerrainRegimeCatalog spec: draw() needs its range, the
    /// hash of its draw group (masked) and whether it scales (*_m) or is a
    /// storey value (*_st, scaled by a feature's height scale).
    internal readonly struct ParamSpec
    {
        public readonly int Id;
        public readonly double Lo, Hi;
        public readonly long GroupHash;
        public readonly bool IsM, IsSt;
        public ParamSpec(int id, double lo, double hi, long groupHash, bool isM, bool isSt)
        {
            Id = id; Lo = lo; Hi = hi; GroupHash = groupHash; IsM = isM; IsSt = isSt;
        }
    }

    internal enum Arch { RollingDowns, RidgeAndPass, EscarpmentCountry, TerracedValleys, KarstHollows, Tableland, HighlandMassif, LowFlats, Unknown }
    internal enum SpKind { Escarpment, BigRidge, Cleft, HangingValley, Unknown }
    internal enum FKind { Hill, PeakCluster, Ridge, Mesa, ButteGroup, TowerCluster, Basin, Valley, Escarpment, Amphitheatre, Unknown }

    internal sealed class FeatureTable
    {
        public double Density;
        public FKind[] Kinds = Array.Empty<FKind>();
        public double[] KindWeights = Array.Empty<double>();
        public double ScaleLo, ScaleHi;
    }

    internal sealed class TerrainTables
    {
        public int ParamCount;
        // Constants by "Script.NAME".
        readonly Dictionary<string, double> _consts = new();

        public Arch[] Archetypes = Array.Empty<Arch>();          // ARCHETYPES order
        public int RollingDownsIndex = -1;
        public string[] ArchetypeNames = Array.Empty<string>();
        public double[][] Affinity = Array.Empty<double[]>();     // [archetype index][biome index], raw table.get(a, 0.0)
        public double[] AltitudeBias = Array.Empty<double>();     // per archetype index
        public ParamSpec[][] ArchParams = Array.Empty<ParamSpec[]>(); // per archetype index
        public SpKind[][] SetpieceKinds = Array.Empty<SpKind[]>();    // per archetype index, dict order
        public double[][] SetpieceDensity = Array.Empty<double[]>();
        public ParamSpec[][] SetpieceParams = new ParamSpec[(int)SpKind.Unknown + 1][];
        public FeatureTable[] Features = Array.Empty<FeatureTable>(); // per archetype index
        public ParamSpec[][] FeatureParams = new ParamSpec[(int)FKind.Unknown + 1][];
        public bool[] Raised = new bool[(int)FKind.Unknown + 1];
        public bool[] Hollow = new bool[(int)FKind.Unknown + 1];
        public bool[] Benched = new bool[(int)FKind.Unknown + 1];

        // Named constants (read once).
        public double REF_AMPLITUDE, SETPIECE_RELIEF_SUPPRESSION, CONTINENTAL_M, ELEVATION_M, SOFT_CEILING,
            FLOOR, UPLAND, SWELL, FRONT_LO, FRONT_HI;
        public double REGION_CELL, BAND_M, BORDER_WARP_M, BORDER_WARP_WL, BASE_NODE, MERGE_CHANCE, SPAWN_CALM_M;
        public double STOREY, AFFINITY_FLOOR;
        public double SP_CELL, SP_FEATHER, SP_SPAWN_CLEAR_M;
        public double F_CELL, F_NORM, F_SPAWN_CLEAR_M, F_HEIGHT_SKEW, F_LINK_MAX_RADIUS, F_LINK_FIRST, F_LINK_SECOND;
        public long F_BLOB_STRIDE;
        public double OCTAVE_TURN;
        public double BIOME_FOREST_SCALE, BIOME_ROCKY_SCALE, BIOME_MOISTURE_SCALE, BIOME_BLOSSOM_SCALE, BIOME_MARSH_SCALE;
        public string[] Biomes = Array.Empty<string>();
        /// Index of each biome_weights5 output (canonical order below) in the
        /// GDScript dictionary's iteration order.
        public int[] BiomeOrder = Array.Empty<int>();

        public static readonly string[] CanonicalBiomes =
            { "meadow", "deep_forest", "highland", "blossom_grove", "twilight_marsh", "amber_heath", "jade_wetlands" };

        readonly Dictionary<string, int> _paramIds = new();

        double C(string key)
        {
            if (!_consts.TryGetValue(key, out double v))
                throw new InvalidOperationException("NativeTerrainHeight: missing constant " + key);
            return v;
        }

        int ParamId(string name)
        {
            if (_paramIds.TryGetValue(name, out int id)) return id;
            id = _paramIds.Count;
            _paramIds[name] = id;
            return id;
        }

        static Arch ArchOf(string n) => n switch
        {
            "rolling_downs" => Arch.RollingDowns, "ridge_and_pass" => Arch.RidgeAndPass,
            "escarpment_country" => Arch.EscarpmentCountry, "terraced_valleys" => Arch.TerracedValleys,
            "karst_hollows" => Arch.KarstHollows, "tableland" => Arch.Tableland,
            "highland_massif" => Arch.HighlandMassif, "low_flats" => Arch.LowFlats, _ => Arch.Unknown,
        };

        public static SpKind SpKindOf(string n) => n switch
        {
            "escarpment" => SpKind.Escarpment, "big_ridge" => SpKind.BigRidge, "cleft" => SpKind.Cleft,
            "hanging_valley" => SpKind.HangingValley, _ => SpKind.Unknown,
        };

        public static FKind FKindOf(string n) => n switch
        {
            "hill" => FKind.Hill, "peak_cluster" => FKind.PeakCluster, "ridge" => FKind.Ridge, "mesa" => FKind.Mesa,
            "butte_group" => FKind.ButteGroup, "tower_cluster" => FKind.TowerCluster, "basin" => FKind.Basin,
            "valley" => FKind.Valley, "escarpment" => FKind.Escarpment, "amphitheatre" => FKind.Amphitheatre,
            _ => FKind.Unknown,
        };

        public int ArchIndex(string name) => Array.IndexOf(ArchetypeNames, name);

        ParamSpec[] Specs(Godot.Collections.Array entries)
        {
            var list = new ParamSpec[entries.Count];
            for (int i = 0; i < entries.Count; i++)
            {
                var e = entries[i].AsGodotArray();
                string name = e[0].AsString();
                list[i] = new ParamSpec(ParamId(name), e[1].AsDouble(), e[2].AsDouble(), e[3].AsInt64(),
                    name.EndsWith("_m", StringComparison.Ordinal), name.EndsWith("_st", StringComparison.Ordinal));
            }
            return list;
        }

        public static TerrainTables From(Godot.Collections.Dictionary t)
        {
            var tb = new TerrainTables();
            foreach (string n in P.Known) tb.ParamId(n);

            var consts = t["consts"].AsGodotDictionary();
            foreach (var kv in consts) tb._consts[kv.Key.AsString()] = kv.Value.AsDouble();

            tb.ArchetypeNames = t["archetypes"].AsStringArray();
            int na = tb.ArchetypeNames.Length;
            tb.Archetypes = new Arch[na];
            for (int i = 0; i < na; i++) tb.Archetypes[i] = ArchOf(tb.ArchetypeNames[i]);
            tb.RollingDownsIndex = tb.ArchIndex("rolling_downs");

            tb.Biomes = t["biomes"].AsStringArray();
            tb.BiomeOrder = new int[tb.Biomes.Length];
            for (int i = 0; i < tb.Biomes.Length; i++)
            {
                tb.BiomeOrder[i] = Array.IndexOf(CanonicalBiomes, tb.Biomes[i]);
                if (tb.BiomeOrder[i] < 0) throw new InvalidOperationException("NativeTerrainHeight: unknown biome " + tb.Biomes[i]);
            }

            var aff = t["affinity"].AsGodotArray();
            tb.Affinity = new double[na][];
            for (int i = 0; i < na; i++) tb.Affinity[i] = aff[i].AsFloat64Array();
            tb.AltitudeBias = t["altitude_bias"].AsFloat64Array();

            var ap = t["params"].AsGodotDictionary();
            tb.ArchParams = new ParamSpec[na][];
            for (int i = 0; i < na; i++) tb.ArchParams[i] = tb.Specs(ap[tb.ArchetypeNames[i]].AsGodotArray());

            var sd = t["setpiece_density"].AsGodotDictionary();
            tb.SetpieceKinds = new SpKind[na][];
            tb.SetpieceDensity = new double[na][];
            for (int i = 0; i < na; i++)
            {
                var rows = sd[tb.ArchetypeNames[i]].AsGodotArray();
                tb.SetpieceKinds[i] = new SpKind[rows.Count];
                tb.SetpieceDensity[i] = new double[rows.Count];
                for (int k = 0; k < rows.Count; k++)
                {
                    var row = rows[k].AsGodotArray();
                    tb.SetpieceKinds[i][k] = SpKindOf(row[0].AsString());
                    tb.SetpieceDensity[i][k] = row[1].AsDouble();
                }
            }
            var spp = t["setpiece_params"].AsGodotDictionary();
            foreach (var kv in spp) tb.SetpieceParams[(int)SpKindOf(kv.Key.AsString())] = tb.Specs(kv.Value.AsGodotArray());

            var ft = t["features"].AsGodotDictionary();
            tb.Features = new FeatureTable[na];
            for (int i = 0; i < na; i++)
            {
                var d = ft[tb.ArchetypeNames[i]].AsGodotDictionary();
                var table = new FeatureTable { Density = d["density"].AsDouble() };
                var kinds = d["kinds"].AsGodotArray();
                table.Kinds = new FKind[kinds.Count];
                table.KindWeights = new double[kinds.Count];
                for (int k = 0; k < kinds.Count; k++)
                {
                    var row = kinds[k].AsGodotArray();
                    table.Kinds[k] = FKindOf(row[0].AsString());
                    table.KindWeights[k] = row[1].AsDouble();
                }
                var hs = d["height_scale"].AsGodotArray();
                table.ScaleLo = hs[0].AsDouble();
                table.ScaleHi = hs[1].AsDouble();
                tb.Features[i] = table;
            }
            var fp = t["feature_params"].AsGodotDictionary();
            foreach (var kv in fp) tb.FeatureParams[(int)FKindOf(kv.Key.AsString())] = tb.Specs(kv.Value.AsGodotArray());
            foreach (string n in t["raised"].AsStringArray()) tb.Raised[(int)FKindOf(n)] = true;
            foreach (string n in t["hollow"].AsStringArray()) tb.Hollow[(int)FKindOf(n)] = true;
            foreach (string n in t["benched"].AsStringArray()) tb.Benched[(int)FKindOf(n)] = true;
            tb.ParamCount = tb._paramIds.Count;

            tb.REF_AMPLITUDE = tb.C("TerrainField.REF_AMPLITUDE");
            tb.SETPIECE_RELIEF_SUPPRESSION = tb.C("TerrainField.SETPIECE_RELIEF_SUPPRESSION");
            tb.CONTINENTAL_M = tb.C("TerrainField.CONTINENTAL_M");
            tb.ELEVATION_M = tb.C("TerrainField.ELEVATION_M");
            tb.SOFT_CEILING = tb.C("TerrainField.SOFT_CEILING");
            tb.FLOOR = tb.C("TerrainField.FLOOR");
            tb.UPLAND = tb.C("TerrainField.UPLAND");
            tb.SWELL = tb.C("TerrainField.SWELL");
            tb.FRONT_LO = tb.C("TerrainField.FRONT_LO");
            tb.FRONT_HI = tb.C("TerrainField.FRONT_HI");
            tb.REGION_CELL = tb.C("TerrainRegimeField.REGION_CELL");
            tb.BAND_M = tb.C("TerrainRegimeField.BAND_M");
            tb.BORDER_WARP_M = tb.C("TerrainRegimeField.BORDER_WARP_M");
            tb.BORDER_WARP_WL = tb.C("TerrainRegimeField.BORDER_WARP_WL");
            tb.BASE_NODE = tb.C("TerrainRegimeField.BASE_NODE");
            tb.MERGE_CHANCE = tb.C("TerrainRegimeField.MERGE_CHANCE");
            tb.SPAWN_CALM_M = tb.C("TerrainRegimeField.SPAWN_CALM_M");
            tb.STOREY = tb.C("TerrainRegimeCatalog.STOREY");
            tb.AFFINITY_FLOOR = tb.C("TerrainRegimeCatalog.AFFINITY_FLOOR");
            tb.SP_CELL = tb.C("LandformSetpieces.CELL");
            tb.SP_FEATHER = tb.C("LandformSetpieces.FEATHER");
            tb.SP_SPAWN_CLEAR_M = tb.C("LandformSetpieces.SPAWN_CLEAR_M");
            tb.F_CELL = tb.C("LandformFeatures.CELL");
            tb.F_NORM = tb.C("LandformFeatures.NORM");
            tb.F_SPAWN_CLEAR_M = tb.C("LandformFeatures.SPAWN_CLEAR_M");
            tb.F_HEIGHT_SKEW = tb.C("LandformFeatures.HEIGHT_SKEW");
            tb.F_LINK_MAX_RADIUS = tb.C("LandformFeatures.LINK_MAX_RADIUS");
            tb.F_LINK_FIRST = tb.C("LandformFeatures.LINK_FIRST");
            tb.F_LINK_SECOND = tb.C("LandformFeatures.LINK_SECOND");
            tb.F_BLOB_STRIDE = (long)tb.C("LandformFeatures.BLOB_STRIDE");
            tb.OCTAVE_TURN = tb.C("ReliefPrimitives.OCTAVE_TURN");
            tb.BIOME_FOREST_SCALE = tb.C("Helper.BIOME_FOREST_SCALE");
            tb.BIOME_ROCKY_SCALE = tb.C("Helper.BIOME_ROCKY_SCALE");
            tb.BIOME_MOISTURE_SCALE = tb.C("Helper.BIOME_MOISTURE_SCALE");
            tb.BIOME_BLOSSOM_SCALE = tb.C("Helper.BIOME_BLOSSOM_SCALE");
            tb.BIOME_MARSH_SCALE = tb.C("Helper.BIOME_MARSH_SCALE");
            return tb;
        }
    }
}
