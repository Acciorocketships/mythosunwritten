// Batch exporter: Unity prefabs/models -> glTF binary (.glb) for Godot.
// Run: Unity -batchmode -nographics -quit -projectPath <clone> -executeMethod GodotExport.Run
// Env: GODOT_EXPORT_OUT = staging directory.
// Unity is left-handed (+Z forward); glTF is right-handed. Positions/normals negate X,
// rotations become (x,-y,-z,w), triangle winding flips and UV V flips (v' = 1 - v).
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEngine;

public static class GodotExport
{
    class Pack { public string root; public string outName; }

    static readonly Pack[] Packs =
    {
        new Pack { root = "Assets/Raygeas/Suntail Village", outName = "Raygeas" },
        new Pack { root = "Assets/Polyart/PolyartStudio", outName = "Polyart" },
        new Pack { root = "Assets/ANGRY MESH", outName = "ANGRY MESH" },
        new Pack { root = "Assets/BK/Pure_Village", outName = "PureVillage" },
        new Pack { root = "Assets/BK/PureNature_Meadows", outName = "PureNatureMeadows" },
        new Pack { root = "Assets/BK/PureNature_Mountains", outName = "PureNatureMountains" },
        new Pack { root = "Assets/BK/PureNature_Redwood", outName = "PureNatureRedwood" },
    };

    // Demo content, Unity-only systems and effect/duplicate folders.
    static readonly string[] Excluded =
    {
        "/Demo/", "/Scenes/", "/Prefabs Terrain Details/", "/DioramaExample/", "/VFX/", "/Effects/",
        "/Particles/", "/FX/", "/Settings/", "/SRP Templates/", "/Post Processing/", "/Animations/",
        "/Terrain Data/", "/Terrain Layers/", "NavMesh", "/Controller.prefab", "/ASP Global Settings/",
        "/Interaction/", "/Skyboxes/", "/ShaderGraph/", "/Shaders/", "/ImportPresets/",
        // Collision proxies, distance impostors, placeholders and shader-only water effects.
        "_COLL.", "TreeCollision", "/Billboards/", "_impostor", "_Impostor", "/SM_Cube", "SM_WaterPlane", "/Waterfalls/",
        // BK Pure Village: smoke/star particles; LOD3 bake textures only serve dropped distance LODs.
        "/Fx/", "/LOD3_Textures/",
        // BK Pure Nature 2: scene manager, shader-only water planes, Unity terrain data.
        "/Environment Manager.prefab", "/Prefabs/Water/", "/Models/Water/", "/Terrains/",
    };
    static readonly string[] TextureExcluded =
    {
        "/Demo/", "/Scenes/", "/Settings/", "/SRP Templates/", "/Post Processing/", "/Skyboxes/", "/Terrain Data/",
        "/LOD3_Textures/", "_Impostor_",
        // BK Pure Nature 2 sky/cloud/water/particle textures serve Unity-only shaders.
        "/Textures/Sky/", "/Textures/Clouds/", "/Textures/Water/", "/Textures/Fx/",
    };
    static readonly HashSet<string> DropSegments = new HashSet<string> { "Assets", "Prefabs", "Meshes", "Models", "Sources", "Textures", "PolyartStudio" };

    static string OutRoot;
    static readonly Dictionary<string, Dictionary<string, object>> TexJobs = new Dictionary<string, Dictionary<string, object>>();
    static readonly HashSet<string> UsedOut = new HashSet<string>();
    static readonly List<Dictionary<string, object>> ModelReport = new List<Dictionary<string, object>>();
    static readonly Dictionary<string, Dictionary<string, object>> MaterialReport = new Dictionary<string, Dictionary<string, object>>();
    static readonly List<string> Warnings = new List<string>();
    static List<(string path, AnimationClip clip, string name)> AnimLibrary;

    // ------------------------------------------------------------------ entry

    public static void Run()
    {
        OutRoot = Environment.GetEnvironmentVariable("GODOT_EXPORT_OUT");
        if (string.IsNullOrEmpty(OutRoot)) throw new Exception("GODOT_EXPORT_OUT not set");
        string only = Environment.GetEnvironmentVariable("GODOT_EXPORT_ONLY"); // optional path substring filter
        Directory.CreateDirectory(OutRoot);

        // Optional: GODOT_EXPORT_PACKS=PureVillage,Raygeas limits the run to those outNames.
        string packFilter = Environment.GetEnvironmentVariable("GODOT_EXPORT_PACKS");
        foreach (var pack in Packs)
        {
            if (packFilter != null && !packFilter.Split(',').Contains(pack.outName)) continue;
            var covered = new HashSet<Mesh>();
            AnimLibrary = CollectAnimationLibrary(pack);

            var prefabPaths = AssetDatabase.FindAssets("t:Prefab", new[] { pack.root })
                .Select(AssetDatabase.GUIDToAssetPath).Where(p => p.EndsWith(".prefab")).Distinct().OrderBy(p => p).ToList();
            // Every prefab (including excluded ones) marks its meshes as covered so the
            // standalone-model pass only emits meshes no prefab presents.
            foreach (var p in prefabPaths)
            {
                var go = AssetDatabase.LoadAssetAtPath<GameObject>(p);
                if (go == null) continue;
                foreach (var mf in go.GetComponentsInChildren<MeshFilter>(true)) if (mf.sharedMesh) covered.Add(mf.sharedMesh);
                foreach (var sm in go.GetComponentsInChildren<SkinnedMeshRenderer>(true)) if (sm.sharedMesh) covered.Add(sm.sharedMesh);
            }
            foreach (var p in prefabPaths)
            {
                if (IsExcluded(p) || (only != null && !only.Split(',').Any(p.Contains))) continue;
                ExportRoot(pack, p, AssetDatabase.LoadAssetAtPath<GameObject>(p), "prefab", null);
            }

            var modelPaths = AssetDatabase.FindAssets("t:Model", new[] { pack.root })
                .Select(AssetDatabase.GUIDToAssetPath).Distinct().OrderBy(p => p).ToList();
            foreach (var p in modelPaths)
            {
                if (IsExcluded(p) || (only != null && !only.Split(',').Any(p.Contains))) continue;
                var go = AssetDatabase.LoadAssetAtPath<GameObject>(p);
                if (go == null) continue;
                ExportRoot(pack, p, go, "model", covered);
            }

            var meshAssets = AssetDatabase.FindAssets("t:Mesh", new[] { pack.root })
                .Select(AssetDatabase.GUIDToAssetPath).Where(p => p.EndsWith(".asset")).Distinct().OrderBy(p => p);
            foreach (var p in meshAssets)
            {
                if (IsExcluded(p) || (only != null && !only.Split(',').Any(p.Contains))) continue;
                var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(p);
                if (mesh == null || covered.Contains(mesh)) continue;
                var go = new GameObject(mesh.name);
                go.AddComponent<MeshFilter>().sharedMesh = mesh;
                go.AddComponent<MeshRenderer>().sharedMaterials = new Material[mesh.subMeshCount];
                ExportRoot(pack, p, go, "mesh_asset", null, alreadyInstance: true);
            }

            if (only == null)
            {
                // All remaining source textures are copied too (shader noise maps, terrain layers, ...).
                foreach (var g in AssetDatabase.FindAssets("t:Texture2D", new[] { pack.root }))
                {
                    var p = AssetDatabase.GUIDToAssetPath(g);
                    if (TextureExcluded.Any(e => ("/" + p).Contains(e))) continue;
                    if (!IsImageFile(p)) continue;
                    TextureOut(pack, p, "copy", null);
                }
            }
        }

        var manifest = new Dictionary<string, object>
        {
            ["textures"] = TexJobs.Values.Cast<object>().ToList(),
            ["models"] = ModelReport.Cast<object>().ToList(),
            ["materials"] = MaterialReport.Values.Cast<object>().ToList(),
            ["warnings"] = Warnings.Cast<object>().ToList(),
        };
        File.WriteAllText(Path.Combine(OutRoot, "export_manifest.json"), Json(manifest));
        Debug.Log($"GODOT_EXPORT done: {ModelReport.Count} models, {TexJobs.Count} textures, {Warnings.Count} warnings");
    }

    static bool IsExcluded(string p) => Excluded.Any(e => ("/" + p).Contains(e));

    static bool IsImageFile(string p)
    {
        var e = Path.GetExtension(p).ToLowerInvariant();
        return e == ".png" || e == ".jpg" || e == ".jpeg" || e == ".tga" || e == ".tif" || e == ".tiff" || e == ".psd" || e == ".bmp" || e == ".exr" || e == ".hdr";
    }

    // ------------------------------------------------------------------ paths

    static string Sanitize(string s)
    {
        var sb = new StringBuilder();
        foreach (var c in s) sb.Append(char.IsLetterOrDigit(c) && c < 128 || c == '.' || c == '-' || c == '_' ? c : '_');
        return sb.ToString();
    }

    static string OutRel(Pack pack, string assetPath, string category, string newExt)
    {
        string rel;
        if (assetPath.StartsWith(pack.root + "/")) rel = assetPath.Substring(pack.root.Length + 1);
        else rel = "_External/" + (assetPath.StartsWith("Assets/") ? assetPath.Substring(7) : assetPath);
        var segs = rel.Split('/').ToList();
        var file = Path.GetFileNameWithoutExtension(segs[segs.Count - 1]);
        segs.RemoveAt(segs.Count - 1);
        segs = segs.Where(s => !DropSegments.Contains(s)).Select(Sanitize).ToList();
        segs.Add(Sanitize(file) + newExt);
        return pack.outName + "/" + category + "/" + string.Join("/", segs);
    }

    static string UniqueOut(string rel)
    {
        if (UsedOut.Add(rel)) return rel;
        var ext = Path.GetExtension(rel); var stem = rel.Substring(0, rel.Length - ext.Length);
        for (int i = 2; ; i++) { var r = $"{stem}_{i}{ext}"; if (UsedOut.Add(r)) return r; }
    }

    // op: copy | ms (unity metallic R + smoothness A) | aa (smoothness in albedo A) | smae (ANGRY MESH S,M,A,E)
    //     | mos (unity metallic R, occlusion G, smoothness A)
    static string TextureOut(Pack pack, string src, string op, float[] args)
    {
        string suffix = op == "copy" ? "" : "_" + op.ToUpperInvariant() + (args == null ? "" : "_" + string.Join("_", args.Select(a => Mathf.RoundToInt(a * 100).ToString())));
        string key = pack.outName + "|" + src + "|" + suffix;
        if (TexJobs.TryGetValue(key, out var job)) return (string)job["out"];
        var ext = Path.GetExtension(src).ToLowerInvariant();
        string newExt = op == "copy" && (ext == ".png" || ext == ".jpg" || ext == ".jpeg") ? ext : ".png";
        var rel = OutRel(pack, src, "Textures", "");
        rel = UniqueOut(rel + suffix + newExt);
        job = new Dictionary<string, object> { ["src"] = src, ["out"] = rel, ["op"] = op };
        if (args != null) job["args"] = args.Cast<object>().ToList();
        TexJobs[key] = job;
        return rel;
    }

    static string RelativeUri(string fromFileRel, string toFileRel)
    {
        var from = fromFileRel.Split('/'); var to = toFileRel.Split('/');
        int common = 0;
        while (common < from.Length - 1 && common < to.Length - 1 && from[common] == to[common]) common++;
        var parts = new List<string>();
        for (int i = common; i < from.Length - 1; i++) parts.Add("..");
        for (int i = common; i < to.Length; i++) parts.Add(to[i]);
        return string.Join("/", parts);
    }

    // ------------------------------------------------------------------ export one root

    static void ExportRoot(Pack pack, string assetPath, GameObject asset, string kind, HashSet<Mesh> coveredForModels, bool alreadyInstance = false)
    {
        if (asset == null) return;
        GameObject inst = alreadyInstance ? asset : (GameObject)UnityEngine.Object.Instantiate(asset);
        try
        {
            inst.SetActive(true);
            inst.name = asset.name;
            var kept = KeptRenderers(inst);
            if (kept.Count == 0) return;
            if (coveredForModels != null && kept.All(r => coveredForModels.Contains(MeshOf(r)))) return;

            string outRel = UniqueOut(OutRel(pack, assetPath, "Models", ".glb"));
            var b = new GlbBuilder(pack, outRel);
            b.Build(inst, kept);
            int anims = 0;
            if (kept.Any(r => r is SkinnedMeshRenderer) || inst.GetComponentInChildren<Animator>(true) != null)
                anims = b.AddAnimations(inst, FindClips(inst));
            var path = Path.Combine(OutRoot, outRel);
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            File.WriteAllBytes(path, b.ToGlb());
            ModelReport.Add(new Dictionary<string, object>
            {
                ["source"] = assetPath, ["out"] = outRel, ["kind"] = kind, ["renderers"] = kept.Count,
                ["skinned"] = kept.Any(r => r is SkinnedMeshRenderer), ["animations"] = anims,
                ["materials"] = b.MaterialNames.Cast<object>().ToList(),
            });
        }
        catch (Exception e)
        {
            Warnings.Add($"{assetPath}: {e.GetType().Name}: {e.Message}");
            Debug.LogException(e);
        }
        finally
        {
            UnityEngine.Object.DestroyImmediate(inst);
        }
    }

    static Mesh MeshOf(Renderer r) =>
        r is SkinnedMeshRenderer s ? s.sharedMesh : r.GetComponent<MeshFilter>() ? r.GetComponent<MeshFilter>().sharedMesh : null;

    // Visible renderers of LOD0 (Godot builds its own LODs on import).
    static List<Renderer> KeptRenderers(GameObject root)
    {
        var dropped = new HashSet<Renderer>();
        foreach (var g in root.GetComponentsInChildren<LODGroup>(true))
        {
            var lods = g.GetLODs();
            if (lods.Length == 0) continue;
            var lod0 = new HashSet<Renderer>(lods[0].renderers.Where(r => r));
            for (int i = 1; i < lods.Length; i++)
                foreach (var r in lods[i].renderers) if (r && !lod0.Contains(r)) dropped.Add(r);
        }
        var result = new List<Renderer>();
        foreach (var r in root.GetComponentsInChildren<Renderer>(true))
        {
            if (!(r is MeshRenderer) && !(r is SkinnedMeshRenderer)) continue;
            if (dropped.Contains(r) || !r.enabled || !r.gameObject.activeInHierarchy) continue;
            var m = MeshOf(r);
            if (m == null || m.vertexCount == 0) continue;
            if (r.name.IndexOf("_LOD", StringComparison.OrdinalIgnoreCase) >= 0 && !r.name.EndsWith("LOD0", StringComparison.OrdinalIgnoreCase)
                && r.GetComponentInParent<LODGroup>() == null && System.Text.RegularExpressions.Regex.IsMatch(r.name, @"_LOD[1-9]$")) continue;
            result.Add(r);
        }
        return result;
    }

    // ------------------------------------------------------------------ animation discovery

    static List<(string, AnimationClip, string)> CollectAnimationLibrary(Pack pack)
    {
        var lib = new List<(string, AnimationClip, string)>();
        var paths = AssetDatabase.FindAssets("t:AnimationClip", new[] { pack.root }).Select(AssetDatabase.GUIDToAssetPath).Distinct();
        foreach (var p in paths)
        {
            var clips = AssetDatabase.LoadAllAssetsAtPath(p).OfType<AnimationClip>().Where(c => !c.name.StartsWith("__preview__")).ToList();
            foreach (var c in clips)
            {
                string file = Path.GetFileNameWithoutExtension(p);
                string name = p.EndsWith(".anim") || clips.Count > 1 && !c.name.Contains("Take") ? c.name : file;
                if (clips.Count > 1 && c.name.Contains("Take")) name = file + "_" + c.name;
                lib.Add((p, c, name));
            }
        }
        return lib;
    }

    static List<(AnimationClip clip, string name, Transform animRoot)> FindClips(GameObject inst)
    {
        var result = new List<(AnimationClip, string, Transform)>();
        var seen = new HashSet<AnimationClip>();
        var candidates = new List<Transform> { inst.transform };
        candidates.AddRange(inst.GetComponentsInChildren<Animator>(true).Select(a => a.transform));
        foreach (Transform c in inst.transform) candidates.Add(c);
        candidates = candidates.Distinct().ToList();

        foreach (var anim in inst.GetComponentsInChildren<Animator>(true))
            if (anim.runtimeAnimatorController != null)
                foreach (var c in anim.runtimeAnimatorController.animationClips)
                    if (c && seen.Add(c)) result.Add((c, c.name, anim.transform));

        foreach (var (path, clip, name) in AnimLibrary)
        {
            if (seen.Contains(clip)) continue;
            var paths = AnimationUtility.GetCurveBindings(clip).Where(bd => bd.type == typeof(Transform)).Select(bd => bd.path).Distinct().ToList();
            if (paths.Count < 3) continue;
            Transform best = null; int bestHit = 0;
            foreach (var root in candidates)
            {
                int hit = paths.Count(p => p.Length == 0 || root.Find(p) != null);
                if (hit > bestHit) { bestHit = hit; best = root; }
            }
            if (best != null && bestHit >= paths.Count * 0.95f && seen.Add(clip)) result.Add((clip, name, best));
        }
        return result;
    }

    // ------------------------------------------------------------------ glb builder

    class GlbBuilder
    {
        readonly Pack pack; readonly string outRel;
        readonly List<object> nodes = new List<object>(), meshes = new List<object>(), materials = new List<object>(),
            textures = new List<object>(), images = new List<object>(), accessors = new List<object>(),
            bufferViews = new List<object>(), skins = new List<object>(), animations = new List<object>();
        readonly MemoryStream bin = new MemoryStream();
        readonly Dictionary<Transform, int> nodeIndex = new Dictionary<Transform, int>();
        readonly Dictionary<Material, int> materialIndex = new Dictionary<Material, int>();
        readonly Dictionary<string, int> imageIndex = new Dictionary<string, int>();
        readonly Dictionary<string, int> meshIndex = new Dictionary<string, int>();
        readonly HashSet<string> extensionsUsed = new HashSet<string>();
        public readonly List<string> MaterialNames = new List<string>();
        int defaultMaterial = -1;
        Transform root;

        public GlbBuilder(Pack pack, string outRel) { this.pack = pack; this.outRel = outRel; }

        public void Build(GameObject go, List<Renderer> kept)
        {
            root = go.transform;
            var needed = new HashSet<Transform>();
            void Mark(Transform t) { for (; t != null && needed.Add(t); t = t.parent) { if (t == root) break; } }
            needed.Add(root);
            foreach (var r in kept)
            {
                Mark(r.transform);
                if (r is SkinnedMeshRenderer s)
                {
                    foreach (var bone in s.bones) if (bone) Mark(bone);
                    if (s.rootBone) Mark(s.rootBone);
                }
            }
            var keptSet = new HashSet<Renderer>(kept);
            AddNode(root, needed, keptSet, true);
            // Skins after all nodes exist.
            foreach (var r in kept.OfType<SkinnedMeshRenderer>())
            {
                var node = (Dictionary<string, object>)nodes[nodeIndex[r.transform]];
                node["skin"] = AddSkin(r);
            }
        }

        int AddNode(Transform t, HashSet<Transform> needed, HashSet<Renderer> kept, bool isRoot)
        {
            var n = new Dictionary<string, object> { ["name"] = t.name };
            int idx = nodes.Count; nodes.Add(n); nodeIndex[t] = idx;
            Vector3 p = isRoot ? Vector3.zero : t.localPosition;
            Quaternion q = t.localRotation; Vector3 s = t.localScale;
            if (p != Vector3.zero) n["translation"] = Floats(-p.x, p.y, p.z);
            if (q != Quaternion.identity) n["rotation"] = Floats(q.x, -q.y, -q.z, q.w);
            if (s != Vector3.one) n["scale"] = Floats(s.x, s.y, s.z);
            var r = t.GetComponent<Renderer>();
            if (r != null && kept.Contains(r)) n["mesh"] = AddMesh(r);
            var children = new List<object>();
            foreach (Transform c in t) if (needed.Contains(c)) children.Add(AddNode(c, needed, kept, false));
            if (children.Count > 0) n["children"] = children;
            return idx;
        }

        // ---------------- meshes

        int AddMesh(Renderer r)
        {
            var mesh = MeshOf(r);
            bool skinned = r is SkinnedMeshRenderer;
            var mats = r.sharedMaterials;
            string key = mesh.GetHashCode() + "|" + skinned + "|" + string.Join(",", mats.Select(m => m ? m.GetHashCode() : 0));
            if (meshIndex.TryGetValue(key, out int existing)) return existing;

            bool vertexColor = mats.Any(m => m && m.shader && m.shader.name.IndexOf("VertexColor", StringComparison.OrdinalIgnoreCase) >= 0);
            var attrs = new Dictionary<string, object>();
            var v = mesh.vertices;
            var pos = new float[v.Length * 3];
            Vector3 min = new Vector3(float.MaxValue, float.MaxValue, float.MaxValue), max = -min;
            for (int i = 0; i < v.Length; i++)
            {
                var c = new Vector3(-v[i].x, v[i].y, v[i].z);
                pos[i * 3] = c.x; pos[i * 3 + 1] = c.y; pos[i * 3 + 2] = c.z;
                min = Vector3.Min(min, c); max = Vector3.Max(max, c);
            }
            attrs["POSITION"] = Accessor(FloatBytes(pos), 5126, v.Length, "VEC3", 34962, Floats(min.x, min.y, min.z), Floats(max.x, max.y, max.z));
            var nrm = mesh.normals;
            if (nrm != null && nrm.Length == v.Length)
            {
                var a = new float[v.Length * 3];
                for (int i = 0; i < v.Length; i++)
                {
                    var nn = nrm[i].sqrMagnitude > 1e-12f ? nrm[i].normalized : Vector3.up;
                    a[i * 3] = -nn.x; a[i * 3 + 1] = nn.y; a[i * 3 + 2] = nn.z;
                }
                attrs["NORMAL"] = Accessor(FloatBytes(a), 5126, v.Length, "VEC3", 34962);
            }
            var uv = new List<Vector2>(); mesh.GetUVs(0, uv);
            if (uv.Count == v.Length)
            {
                var a = new float[v.Length * 2];
                for (int i = 0; i < v.Length; i++) { a[i * 2] = uv[i].x; a[i * 2 + 1] = 1f - uv[i].y; }
                attrs["TEXCOORD_0"] = Accessor(FloatBytes(a), 5126, v.Length, "VEC2", 34962);
            }
            if (vertexColor)
            {
                var col = mesh.colors;
                if (col != null && col.Length == v.Length)
                {
                    var a = new float[v.Length * 4];
                    for (int i = 0; i < v.Length; i++) { var c = col[i].linear; a[i * 4] = c.r; a[i * 4 + 1] = c.g; a[i * 4 + 2] = c.b; a[i * 4 + 3] = c.a; }
                    attrs["COLOR_0"] = Accessor(FloatBytes(a), 5126, v.Length, "VEC4", 34962);
                }
            }
            if (skinned)
            {
                var bw = mesh.boneWeights;
                if (bw != null && bw.Length == v.Length)
                {
                    var j = new ushort[v.Length * 4]; var w = new float[v.Length * 4];
                    for (int i = 0; i < v.Length; i++)
                    {
                        var x = bw[i]; float sum = x.weight0 + x.weight1 + x.weight2 + x.weight3; if (sum <= 0) sum = 1;
                        j[i * 4] = (ushort)x.boneIndex0; j[i * 4 + 1] = (ushort)x.boneIndex1; j[i * 4 + 2] = (ushort)x.boneIndex2; j[i * 4 + 3] = (ushort)x.boneIndex3;
                        w[i * 4] = x.weight0 / sum; w[i * 4 + 1] = x.weight1 / sum; w[i * 4 + 2] = x.weight2 / sum; w[i * 4 + 3] = x.weight3 / sum;
                    }
                    var jb = new byte[j.Length * 2]; Buffer.BlockCopy(j, 0, jb, 0, jb.Length);
                    attrs["JOINTS_0"] = Accessor(jb, 5123, v.Length, "VEC4", 34962);
                    attrs["WEIGHTS_0"] = Accessor(FloatBytes(w), 5126, v.Length, "VEC4", 34962);
                }
            }

            var prims = new List<object>();
            for (int sub = 0; sub < mesh.subMeshCount; sub++)
            {
                if (mesh.GetTopology(sub) != MeshTopology.Triangles) continue;
                var idx = mesh.GetIndices(sub);
                if (idx.Length < 3) continue;
                for (int i = 0; i + 2 < idx.Length; i += 3) { var t = idx[i + 1]; idx[i + 1] = idx[i + 2]; idx[i + 2] = t; }
                int acc;
                if (v.Length <= 65535)
                {
                    var s = new ushort[idx.Length]; for (int i = 0; i < idx.Length; i++) s[i] = (ushort)idx[i];
                    var bb = new byte[s.Length * 2]; Buffer.BlockCopy(s, 0, bb, 0, bb.Length);
                    acc = Accessor(bb, 5123, idx.Length, "SCALAR", 34963);
                }
                else
                {
                    var bb = new byte[idx.Length * 4]; Buffer.BlockCopy(idx, 0, bb, 0, bb.Length);
                    acc = Accessor(bb, 5125, idx.Length, "SCALAR", 34963);
                }
                var mat = sub < mats.Length ? mats[sub] : (mats.Length > 0 ? mats[mats.Length - 1] : null);
                prims.Add(new Dictionary<string, object> { ["attributes"] = attrs, ["indices"] = acc, ["material"] = MaterialFor(mat) });
            }
            int mi = meshes.Count;
            meshes.Add(new Dictionary<string, object> { ["name"] = mesh.name, ["primitives"] = prims });
            meshIndex[key] = mi;
            return mi;
        }

        int AddSkin(SkinnedMeshRenderer r)
        {
            var bones = r.bones; var bind = r.sharedMesh.bindposes;
            var joints = new List<object>(); var ibm = new float[bones.Length * 16];
            for (int i = 0; i < bones.Length; i++)
            {
                var bone = bones[i] ? bones[i] : root;
                joints.Add(nodeIndex.TryGetValue(bone, out int ni) ? ni : 0);
                var m = i < bind.Length ? bind[i] : Matrix4x4.identity;
                var c = Mirror(m);
                for (int col = 0; col < 4; col++) for (int row = 0; row < 4; row++) ibm[i * 16 + col * 4 + row] = c[row, col];
            }
            int acc = Accessor(FloatBytes(ibm), 5126, bones.Length, "MAT4", null);
            var skin = new Dictionary<string, object> { ["joints"] = joints, ["inverseBindMatrices"] = acc, ["name"] = r.name };
            if (r.rootBone && nodeIndex.TryGetValue(r.rootBone, out int rb)) skin["skeleton"] = rb;
            skins.Add(skin);
            return skins.Count - 1;
        }

        static Matrix4x4 Mirror(Matrix4x4 m)
        {
            var c = Matrix4x4.Scale(new Vector3(-1, 1, 1));
            return c * m * c;
        }

        // ---------------- animations (sampled from the Unity rig; generic clips)

        public int AddAnimations(GameObject inst, List<(AnimationClip clip, string name, Transform animRoot)> clips)
        {
            if (clips.Count == 0) return 0;
            var animated = nodeIndex.Keys.ToList();
            var rest = animated.ToDictionary(t => t, t => (t.localPosition, t.localRotation, t.localScale));
            var usedNames = new HashSet<string>();
            foreach (var (clip, rawName, animRoot) in clips)
            {
                var bound = new HashSet<Transform>();
                foreach (var bd in AnimationUtility.GetCurveBindings(clip))
                {
                    if (bd.type != typeof(Transform)) continue;
                    var tt = bd.path.Length == 0 ? animRoot : animRoot.Find(bd.path);
                    if (tt != null && nodeIndex.ContainsKey(tt)) bound.Add(tt);
                }
                if (bound.Count == 0) continue;
                foreach (var kv in rest) { kv.Key.localPosition = kv.Value.Item1; kv.Key.localRotation = kv.Value.Item2; kv.Key.localScale = kv.Value.Item3; }
                float fps = Mathf.Clamp(clip.frameRate > 0 ? clip.frameRate : 30f, 1f, 30f);
                int frames = Mathf.Max(2, Mathf.CeilToInt(clip.length * fps) + 1);
                var order = bound.ToList();
                var T = order.ToDictionary(t => t, t => new Vector3[frames]);
                var R = order.ToDictionary(t => t, t => new Quaternion[frames]);
                var S = order.ToDictionary(t => t, t => new Vector3[frames]);
                var times = new float[frames];
                for (int f = 0; f < frames; f++)
                {
                    float time = Mathf.Min(clip.length, f / fps);
                    times[f] = time;
                    clip.SampleAnimation(animRoot.gameObject, time);
                    foreach (var t in order) { T[t][f] = t.localPosition; R[t][f] = t.localRotation; S[t][f] = t.localScale; }
                }
                foreach (var kv in rest) { kv.Key.localPosition = kv.Value.Item1; kv.Key.localRotation = kv.Value.Item2; kv.Key.localScale = kv.Value.Item3; }

                int input = Accessor(FloatBytes(times), 5126, frames, "SCALAR", null, Floats(times[0]), Floats(times[frames - 1]));
                var samplers = new List<object>(); var channels = new List<object>();
                foreach (var t in order)
                {
                    int node = nodeIndex[t];
                    var tr = new float[frames * 3]; var ro = new float[frames * 4]; var sc = new float[frames * 3];
                    bool moveT = false, moveS = false; Quaternion prev = R[t][0];
                    for (int f = 0; f < frames; f++)
                    {
                        var p = T[t][f]; tr[f * 3] = -p.x; tr[f * 3 + 1] = p.y; tr[f * 3 + 2] = p.z;
                        var q = R[t][f]; if (Quaternion.Dot(prev, q) < 0) q = new Quaternion(-q.x, -q.y, -q.z, -q.w); prev = q;
                        ro[f * 4] = q.x; ro[f * 4 + 1] = -q.y; ro[f * 4 + 2] = -q.z; ro[f * 4 + 3] = q.w;
                        var s = S[t][f]; sc[f * 3] = s.x; sc[f * 3 + 1] = s.y; sc[f * 3 + 2] = s.z;
                        if ((p - rest[t].Item1).sqrMagnitude > 1e-10f) moveT = true;
                        if ((s - rest[t].Item3).sqrMagnitude > 1e-10f) moveS = true;
                    }
                    void Channel(string path, float[] data, string type)
                    {
                        samplers.Add(new Dictionary<string, object> { ["input"] = input, ["output"] = Accessor(FloatBytes(data), 5126, frames, type, null), ["interpolation"] = "LINEAR" });
                        channels.Add(new Dictionary<string, object> { ["sampler"] = samplers.Count - 1, ["target"] = new Dictionary<string, object> { ["node"] = node, ["path"] = path } });
                    }
                    Channel("rotation", ro, "VEC4");
                    if (moveT) Channel("translation", tr, "VEC3");
                    if (moveS) Channel("scale", sc, "VEC3");
                }
                string name = rawName; for (int i = 2; !usedNames.Add(name); i++) name = rawName + "_" + i;
                animations.Add(new Dictionary<string, object> { ["name"] = name, ["samplers"] = samplers, ["channels"] = channels });
            }
            return animations.Count;
        }

        // ---------------- materials

        int MaterialFor(Material m)
        {
            if (m == null)
            {
                if (defaultMaterial < 0)
                {
                    defaultMaterial = materials.Count;
                    materials.Add(new Dictionary<string, object> { ["name"] = "Default", ["pbrMetallicRoughness"] = new Dictionary<string, object> { ["metallicFactor"] = 0.0, ["roughnessFactor"] = 0.9 } });
                }
                return defaultMaterial;
            }
            if (materialIndex.TryGetValue(m, out int idx)) return idx;
            idx = materials.Count;
            materials.Add(ConvertMaterial(m));
            materialIndex[m] = idx;
            MaterialNames.Add(m.name);
            return idx;
        }

        Dictionary<string, object> TexInfo(string texOutRel, Dictionary<string, object> transform, string extraKey = null, double extraValue = 1.0)
        {
            string uri = RelativeUri(outRel, texOutRel);
            if (!imageIndex.TryGetValue(uri, out int ti))
            {
                images.Add(new Dictionary<string, object> { ["uri"] = uri, ["name"] = Path.GetFileNameWithoutExtension(texOutRel) });
                textures.Add(new Dictionary<string, object> { ["source"] = images.Count - 1, ["sampler"] = 0 });
                ti = textures.Count - 1; imageIndex[uri] = ti;
            }
            var info = new Dictionary<string, object> { ["index"] = ti };
            if (extraKey != null) info[extraKey] = extraValue;
            if (transform != null)
            {
                info["extensions"] = new Dictionary<string, object> { ["KHR_texture_transform"] = transform };
                extensionsUsed.Add("KHR_texture_transform");
            }
            return info;
        }

        Dictionary<string, object> ConvertMaterial(Material m)
        {
            var mp = new MatProps(m);
            string sn = m.shader ? m.shader.name : "";
            var report = new Dictionary<string, object> { ["material"] = AssetDatabase.GetAssetPath(m), ["name"] = m.name, ["shader"] = sn };
            var pbr = new Dictionary<string, object>();
            var mat = new Dictionary<string, object> { ["name"] = m.name, ["pbrMetallicRoughness"] = pbr };

            // Base colour texture + tint
            string albedoProp = mp.FirstTex("_BaseAlbedo", "_Albedo", "_AlbedoTexture", "_BaseMap", "_ColorMap", "_Color_Map", "_Base_Color",
                "_Layer_01_Color", "_Diffuse", "_Foliage_Map", "_MainTex", "Material_Texture2D_0", "_Texture", "_Cloud_Texture", "_Fire_Texture", "_Albedo_Map");
            Color tint = Color.white; string tintProp = null;
            if (mp.Has("_BaseAlbedoColor"))
            {
                // ANGRY MESH: overlay blend with a 0.5-grey neutral, then brightness.
                var c = mp.Col("_BaseAlbedoColor").Value; float br = mp.Flt("_BaseAlbedoBrightness") ?? 1f;
                tint = new Color(Mathf.Clamp01(2 * c.r * br), Mathf.Clamp01(2 * c.g * br), Mathf.Clamp01(2 * c.b * br), 1);
                tintProp = "_BaseAlbedoColor";
            }
            else if (mp.Has("_Color_Base") && mp.Has("_Color_Top"))
            {
                tint = Color.Lerp(mp.Col("_Color_Base").Value, mp.Col("_Color_Top").Value, 0.5f); tintProp = "_Color_Base/_Color_Top";
            }
            else if (mp.Has("_Color01") && mp.Has("_Color02"))
            {
                // BK Pure Village grass/flowers: noise blend between two tints.
                tint = Color.Lerp(mp.Col("_Color01").Value, mp.Col("_Color02").Value, 0.5f); tintProp = "_Color01/_Color02";
            }
            else if (mp.Has("_Foliage_Color_Top") && mp.Has("_Foliage_Color_Bottom"))
            {
                tint = Color.Lerp(mp.Col("_Foliage_Color_Bottom").Value, mp.Col("_Foliage_Color_Top").Value, 0.5f); tintProp = "_Foliage_Color_Bottom/_Foliage_Color_Top";
            }
            else
            {
                tintProp = new[] { "_ColorTint", "_Color_Tint", "_Layer_01_Tint", "_MainColor", "_BaseColor", "_Color", "_Tint" }.FirstOrDefault(p => mp.Col(p).HasValue);
                if (tintProp != null) tint = mp.Col(tintProp).Value;
            }

            // Alpha mode
            int queue = m.renderQueue;
            // Foliage shaders (Suntail, ANGRY MESH, Polyart, BK) clip albedo alpha in-shader at opaque queue.
            bool clip = sn == "BK/Grass" || sn == "BK/Vegetation Leaves" || m.IsKeywordEnabled("_ALPHATEST_ON") || (mp.Flt("_AlphaClip") ?? 0) > 0.5f || (mp.Flt("_BUILTIN_AlphaClip") ?? 0) > 0.5f
                || mp.Flt("_AlphaCutoff", "_CutOff", "_BaseOpacityCutoff", "_Alpha_Clip", "_AlphaClipThreshold", "_AlphaClippingTreshold").HasValue;
            string alphaMode = queue >= 3000 ? "BLEND" : (queue >= 2450 || clip) ? "MASK" : "OPAQUE";
            if (alphaMode != "OPAQUE" && albedoProp == null && tint.a >= 0.999f) alphaMode = "OPAQUE";
            if (alphaMode == "MASK") mat["alphaCutoff"] = (double)Mathf.Clamp(mp.Flt("_Cutoff", "_AlphaCutoff", "_CutOff", "_BaseOpacityCutoff", "_Alpha_Clip", "_AlphaClipThreshold", "_AlphaClippingTreshold") ?? 0.5f, 0.01f, 0.99f);
            if (alphaMode != "OPAQUE") mat["alphaMode"] = alphaMode;
            float cull = mp.Flt("_Cull", "_CullMode", "_BUILTIN_CullMode", "_RenderFace") ?? 2f;
            if (cull < 0.5f || alphaMode == "MASK") mat["doubleSided"] = true;

            var lin = tint.linear;
            pbr["baseColorFactor"] = new List<object> { (double)lin.r, (double)lin.g, (double)lin.b, alphaMode == "BLEND" ? (double)tint.a : 1.0 };

            Dictionary<string, object> xf = null;
            if (albedoProp != null)
            {
                var sc = m.GetTextureScale(albedoProp); var of = m.GetTextureOffset(albedoProp);
                float uvScale = mp.Flt("_BaseUVScale") ?? 1f;
                sc *= uvScale;
                if (sc != Vector2.one || of != Vector2.zero)
                    xf = new Dictionary<string, object> { ["scale"] = Floats(sc.x, sc.y), ["offset"] = Floats(of.x, 1f - sc.y - of.y) };
                pbr["baseColorTexture"] = TexInfo(TextureOut(pack, mp.TexPath(albedoProp), "copy", null), xf);
            }
            report["albedo"] = albedoProp; report["tint"] = tintProp; report["alpha"] = alphaMode;

            // Normal
            string normalProp = mp.FirstTex("_BaseNormal", "_Normal", "_NormalMap", "_Normal_Map", "_BumpMap", "_Layer_01_Normal");
            float nScale = mp.Flt("_BaseNormalIntensity", "_NormalPower", "_NormalScale", "_BumpScale", "_Normal_Intensity", "_NormalIntensity", "_Layer_01_Normal_Strength") ?? 1f;
            if (normalProp != null && nScale > 0.01f)
                mat["normalTexture"] = TexInfo(TextureOut(pack, mp.TexPath(normalProp), "copy", null), xf, "scale", Mathf.Clamp(nScale, 0f, 2f));
            report["normal"] = normalProp;

            // Metallic / roughness / occlusion
            string ormProp = mp.FirstTex("_ORMMap", "_ORM_Map", "_Layer_01_ORM");
            string msProp = mp.FirstTex("_MetallicSmoothness", "_MetallicGlossMap", "_MetallicROcclusionGSmoothnessA");
            string smaeProp = mp.FirstTex("_BaseSMAE");
            if (ormProp != null)
            {
                var info = TexInfo(TextureOut(pack, mp.TexPath(ormProp), "copy", null), xf);
                pbr["metallicRoughnessTexture"] = info;
                pbr["metallicFactor"] = (double)Mathf.Clamp01(mp.Flt("_MetallicIntensity", "_Metallic_Intensity", "_Layer_01_Metallic") ?? 1f);
                pbr["roughnessFactor"] = (double)Mathf.Clamp01(mp.Flt("_RoughnessIntensity", "_Roughness_Intensity", "_Layer_01_Roughness") ?? 1f);
                mat["occlusionTexture"] = TexInfo(TextureOut(pack, mp.TexPath(ormProp), "copy", null), xf, "strength", Mathf.Clamp01(mp.Flt("_AOIntensity", "_AO_Intensity", "_Layer_01_AO") ?? 1f));
                report["mr"] = ormProp + " (ORM)";
            }
            else if (msProp != null && (sn == "BK/Standard Layered" || sn == "BK/Vegetation Trunk"
                || (sn == "Universal Render Pipeline/Lit" && m.IsKeywordEnabled("_METALLICSPECGLOSSMAP") && (mp.Flt("_SmoothnessTextureChannel") ?? 0f) < 0.5f)))
            {
                // Unity metallic map: R metallic, G occlusion, A smoothness. BK Pure Village's
                // layered shader reads occlusion from G of the same map; URP Lit uses a separate
                // _OcclusionMap slot, combined here only when it names the same texture.
                bool bk = sn.StartsWith("BK/");
                float s = Mathf.Clamp01((bk ? mp.Flt("_SmoothnessPower") : mp.Flt("_Smoothness")) ?? 0.5f);
                string occProp = bk ? msProp : mp.FirstTex("_OcclusionMap");
                bool occ = occProp != null && mp.TexPath(occProp) == mp.TexPath(msProp);
                float occStrength = occ ? Mathf.Clamp01((bk ? mp.Flt("_OcclusionPower") : mp.Flt("_OcclusionStrength")) ?? 1f) : 0f;
                var outTex = TextureOut(pack, mp.TexPath(msProp), "mos", new[] { s, occStrength });
                pbr["metallicRoughnessTexture"] = TexInfo(outTex, xf);
                pbr["metallicFactor"] = (double)(bk ? Mathf.Clamp01(mp.Flt("_MetallicPower") ?? 0f) : 1f);
                pbr["roughnessFactor"] = 1.0;
                if (occStrength > 0.01f) mat["occlusionTexture"] = TexInfo(outTex, xf, "strength", 1f);
                report["mr"] = msProp + $" (MOS smoothness x{s}, AO x{occStrength})";
            }
            else if (msProp != null && mp.Has("_SurfaceSmoothness"))
            {
                float s = Mathf.Clamp01(mp.Flt("_SurfaceSmoothness") ?? 0f);
                bool fromAlbedo = m.IsKeywordEnabled("_SMOOTHNESSSOURCE_ALBEDO_ALPHA") && albedoProp != null;
                var outTex = fromAlbedo ? TextureOut(pack, mp.TexPath(albedoProp), "aa", new[] { s }) : TextureOut(pack, mp.TexPath(msProp), "ms", new[] { s });
                pbr["metallicRoughnessTexture"] = TexInfo(outTex, xf);
                pbr["metallicFactor"] = (double)Mathf.Clamp01(mp.Flt("_Metallic") ?? 0f);
                pbr["roughnessFactor"] = 1.0;
                report["mr"] = (fromAlbedo ? albedoProp : msProp) + $" (smoothness x{s})";
            }
            else if (smaeProp != null)
            {
                float lo = mp.Flt("_BaseSmoothnessMin") ?? 0f, hi = mp.Flt("_BaseSmoothnessMax") ?? 1f;
                var outTex = TextureOut(pack, mp.TexPath(smaeProp), "smae", new[] { lo, hi });
                pbr["metallicRoughnessTexture"] = TexInfo(outTex, xf);
                pbr["metallicFactor"] = (double)Mathf.Clamp01(mp.Flt("_BaseMetallicIntensity") ?? 0f);
                pbr["roughnessFactor"] = 1.0;
                mat["occlusionTexture"] = TexInfo(outTex, xf, "strength", Mathf.Clamp01(mp.Flt("_BaseAOIntensity") ?? 0.5f));
                report["mr"] = smaeProp + " (SMAE)";
            }
            else
            {
                float? smooth = mp.Flt("_Smoothness", "_Glossiness", "_SurfaceSmoothness", "_BaseSmoothnessIntensity", "_Roughness_Inverse");
                float? rough = mp.Flt("_Roughness", "_Layer_01_Roughness");
                pbr["metallicFactor"] = (double)Mathf.Clamp01(mp.Flt("_Metallic", "_BaseMetallicIntensity") ?? 0f);
                pbr["roughnessFactor"] = (double)Mathf.Clamp(rough ?? (smooth.HasValue ? 1f - smooth.Value : 0.9f), 0.05f, 1f);
            }

            // Emission
            bool urpLit = sn.StartsWith("Universal Render Pipeline/") || sn == "Standard";
            string emTexProp = smaeProp != null ? null : mp.FirstTex("_EmissionMap", "_Emission", "_Emissive_Map", "_Layer_01_Emissive");
            var emCol = mp.Col("_EmissionColor", "_EmissiveColor", "_Emissive_Color", "_Emissive", "_Layer_01_Emissive_Color");
            float emInt = mp.Flt("_EmissiveIntensity", "_Emissive_Intensity") ?? 1f;
            // Vendor shaders gate emission behind a map or a keyword (_EMISSION, _USE_EMISSIVE, ...);
            // a colour alone does not glow.
            bool emEnabled = emTexProp != null || m.shaderKeywords.Any(k => k.IndexOf("EMISSI", StringComparison.OrdinalIgnoreCase) >= 0);
            if (smaeProp == null && emCol.HasValue && emEnabled && (!urpLit || m.IsKeywordEnabled("_EMISSION")))
            {
                var e = emCol.Value.linear * emInt;
                float peak = Mathf.Max(e.r, e.g, e.b);
                if (peak > 0.004f)
                {
                    float strength = Mathf.Max(1f, peak);
                    mat["emissiveFactor"] = Floats(e.r / strength, e.g / strength, e.b / strength);
                    if (strength > 1f)
                    {
                        mat["extensions"] = new Dictionary<string, object> { ["KHR_materials_emissive_strength"] = new Dictionary<string, object> { ["emissiveStrength"] = (double)strength } };
                        extensionsUsed.Add("KHR_materials_emissive_strength");
                    }
                    if (emTexProp != null) mat["emissiveTexture"] = TexInfo(TextureOut(pack, mp.TexPath(emTexProp), "copy", null), xf);
                    report["emission"] = emTexProp ?? "color";
                }
            }
            string mpath = AssetDatabase.GetAssetPath(m);
            MaterialReport[pack.outName + "|" + mpath + "|" + m.name] = report;
            return mat;
        }

        // ---------------- buffers / serialization

        int Accessor(byte[] data, int componentType, int count, string type, int? target, List<object> min = null, List<object> max = null)
        {
            while (bin.Length % 4 != 0) bin.WriteByte(0);
            long offset = bin.Length;
            bin.Write(data, 0, data.Length);
            var bv = new Dictionary<string, object> { ["buffer"] = 0, ["byteOffset"] = offset, ["byteLength"] = data.Length };
            if (target.HasValue) bv["target"] = target.Value;
            bufferViews.Add(bv);
            var acc = new Dictionary<string, object> { ["bufferView"] = bufferViews.Count - 1, ["componentType"] = componentType, ["count"] = count, ["type"] = type };
            if (min != null) acc["min"] = min;
            if (max != null) acc["max"] = max;
            accessors.Add(acc);
            return accessors.Count - 1;
        }

        public byte[] ToGlb()
        {
            while (bin.Length % 4 != 0) bin.WriteByte(0);
            var gltf = new Dictionary<string, object>
            {
                ["asset"] = new Dictionary<string, object> { ["version"] = "2.0", ["generator"] = "Unity->Godot batch exporter" },
                ["scene"] = 0,
                ["scenes"] = new List<object> { new Dictionary<string, object> { ["nodes"] = new List<object> { 0 } } },
                ["nodes"] = nodes, ["meshes"] = meshes, ["materials"] = materials,
                ["accessors"] = accessors, ["bufferViews"] = bufferViews,
                ["buffers"] = new List<object> { new Dictionary<string, object> { ["byteLength"] = bin.Length } },
            };
            if (textures.Count > 0)
            {
                gltf["textures"] = textures; gltf["images"] = images;
                gltf["samplers"] = new List<object> { new Dictionary<string, object> { ["magFilter"] = 9729, ["minFilter"] = 9987, ["wrapS"] = 10497, ["wrapT"] = 10497 } };
            }
            if (skins.Count > 0) gltf["skins"] = skins;
            if (animations.Count > 0) gltf["animations"] = animations;
            if (extensionsUsed.Count > 0) gltf["extensionsUsed"] = extensionsUsed.Cast<object>().ToList();
            var json = Encoding.UTF8.GetBytes(Json(gltf));
            int jsonPad = (4 - json.Length % 4) % 4;
            var binBytes = bin.ToArray();
            using (var ms = new MemoryStream())
            using (var w = new BinaryWriter(ms))
            {
                int total = 12 + 8 + json.Length + jsonPad + 8 + binBytes.Length;
                w.Write(0x46546C67); w.Write(2); w.Write(total);
                w.Write(json.Length + jsonPad); w.Write(0x4E4F534A); w.Write(json); for (int i = 0; i < jsonPad; i++) w.Write((byte)0x20);
                w.Write(binBytes.Length); w.Write(0x004E4942); w.Write(binBytes);
                return ms.ToArray();
            }
        }
    }

    // ------------------------------------------------------------------ material property access
    // Reads saved values; when the shader compiled, stale saved properties the shader
    // no longer declares are ignored.

    class MatProps
    {
        readonly Material m; readonly bool shaderValid;
        readonly Dictionary<string, Texture> tex = new Dictionary<string, Texture>();
        readonly Dictionary<string, Color> col = new Dictionary<string, Color>();
        readonly Dictionary<string, float> flt = new Dictionary<string, float>();

        public MatProps(Material m)
        {
            this.m = m;
            shaderValid = m.shader != null && m.shader.name != "Hidden/InternalErrorShader" && m.shader.GetPropertyCount() > 0;
            var so = new SerializedObject(m);
            var envs = so.FindProperty("m_SavedProperties.m_TexEnvs");
            for (int i = 0; envs != null && i < envs.arraySize; i++)
            {
                var e = envs.GetArrayElementAtIndex(i);
                tex[e.FindPropertyRelative("first").stringValue] = e.FindPropertyRelative("second.m_Texture").objectReferenceValue as Texture;
            }
            var cols = so.FindProperty("m_SavedProperties.m_Colors");
            for (int i = 0; cols != null && i < cols.arraySize; i++)
            {
                var e = cols.GetArrayElementAtIndex(i);
                col[e.FindPropertyRelative("first").stringValue] = e.FindPropertyRelative("second").colorValue;
            }
            var fl = so.FindProperty("m_SavedProperties.m_Floats");
            for (int i = 0; fl != null && i < fl.arraySize; i++)
            {
                var e = fl.GetArrayElementAtIndex(i);
                flt[e.FindPropertyRelative("first").stringValue] = e.FindPropertyRelative("second").floatValue;
            }
        }

        bool Declared(string p) => !shaderValid || m.HasProperty(p);
        public bool Has(string p) => Declared(p) && (tex.ContainsKey(p) || col.ContainsKey(p) || flt.ContainsKey(p));

        public string FirstTex(params string[] names) =>
            names.FirstOrDefault(n => Declared(n) && tex.TryGetValue(n, out var t) && t is Texture2D && IsImageFile(AssetDatabase.GetAssetPath(t)));

        public string TexPath(string p) => AssetDatabase.GetAssetPath(tex[p]);

        public string TexDefault(string p)
        {
            if (!shaderValid) return "black";
            int i = m.shader.FindPropertyIndex(p);
            return i < 0 ? "black" : m.shader.GetPropertyTextureDefaultName(i);
        }

        public Color? Col(params string[] names)
        {
            foreach (var n in names) if (Declared(n) && col.TryGetValue(n, out var c)) return c;
            return null;
        }

        public float? Flt(params string[] names)
        {
            foreach (var n in names) if (Declared(n) && flt.TryGetValue(n, out var f)) return f;
            return null;
        }
    }

    // ------------------------------------------------------------------ helpers

    static List<object> Floats(params float[] v) => v.Select(x => (object)(double)x).ToList();

    static byte[] FloatBytes(float[] a)
    {
        var b = new byte[a.Length * 4];
        Buffer.BlockCopy(a, 0, b, 0, b.Length);
        return b;
    }

    static string Json(object o)
    {
        var sb = new StringBuilder();
        WriteJson(sb, o);
        return sb.ToString();
    }

    static void WriteJson(StringBuilder sb, object o)
    {
        switch (o)
        {
            case null: sb.Append("null"); break;
            case string s:
                sb.Append('"');
                foreach (var c in s)
                {
                    if (c == '"' || c == '\\') sb.Append('\\').Append(c);
                    else if (c < 0x20) sb.Append("\\u").Append(((int)c).ToString("x4"));
                    else sb.Append(c);
                }
                sb.Append('"');
                break;
            case bool b: sb.Append(b ? "true" : "false"); break;
            case int i: sb.Append(i.ToString(CultureInfo.InvariantCulture)); break;
            case long l: sb.Append(l.ToString(CultureInfo.InvariantCulture)); break;
            case float f: sb.Append(Num(f)); break;
            case double d: sb.Append(Num(d)); break;
            case System.Collections.IDictionary dict:
                sb.Append('{'); bool first = true;
                foreach (System.Collections.DictionaryEntry kv in dict)
                {
                    if (!first) sb.Append(','); first = false;
                    WriteJson(sb, kv.Key.ToString()); sb.Append(':'); WriteJson(sb, kv.Value);
                }
                sb.Append('}');
                break;
            case System.Collections.IEnumerable list:
                sb.Append('['); bool f1 = true;
                foreach (var x in list) { if (!f1) sb.Append(','); f1 = false; WriteJson(sb, x); }
                sb.Append(']');
                break;
            default: WriteJson(sb, o.ToString()); break;
        }
    }

    static string Num(double d)
    {
        if (double.IsNaN(d) || double.IsInfinity(d)) return "0";
        return d.ToString("R", CultureInfo.InvariantCulture);
    }
}
