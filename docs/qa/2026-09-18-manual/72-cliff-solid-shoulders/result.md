# Actual rock-volume studies

The owner's request is physical bumps, outcroppings and irregular formations, with an integrated wall composition. No material, normal map or texture was changed in this pass. Production remains the pass-69 geometry; none of the following candidates met the visual standard.

## Candidates and native review

- **Sculpted shoulders:** asymmetric solid depth additions, with whole-tread translations to preserve cap surfaces. This still reads as a smooth wall with upright bulges. The upper-volume test fails its quiet-area assertion: 48,886 of 52,094 sampled vertices move over 0.15 m, leaving only 2,556 quiet samples. Maximum movement is 0.9527 m; the crown remains unchanged. Five of six assertions pass, not an acceptance.
- **Finite shoulders:** bounded lower extent and stronger oblique planes. The matched view exposes a conspicuous hanging oval and dark edge. Rejected.
- **Native solids:** subdivided original bare Nature Pack Rock 3/4/5/6 triangles, partly embedded in the real generated face. The lower rocks add actual source silhouettes. A follow-up places varied smaller solids farther up the wall. Seventeen frozen-world views plus a 32 m tall study were rendered; P20 oblique, P12 side and tall oblique were directly inspected. The tall study clearly looks like individual climbing-wall holds. Rejected for composition and attachment.
- **Integral bodies:** bare-rock front shapes replace the prior underlying mass field before ledge construction. The matched view remains too plain and changes the ground junction. Rejected.

## Physical evidence for native-solids prototype

The no-addition baseline fails two of six assertions: it has no additional triangles and no newly exposed volume. The native-clusters candidate passes all six assertions. It adds 59,424 vertices, including 18,075 sampled points over 0.2 m beyond the baseline face. Maximum sampled projection is 1.5231 m. Added shells have zero unmatched edges and zero degenerate triangles. Existing turf triangles remain identical and the crown height is preserved. These measurements concern the prototype's generated mesh, not a fresh terrain or gameplay acceptance.

The original meshes are CC0 Ultimate Nature Pack assets. `bake_native_solids.py` reproduces their detached study arrays without runtime source-pack loading. Midpoint subdivision preserves source planes while allowing their buried portions to follow the backing surface.

All launched processes exited. Frozen replays do not regenerate terrain grass, water admission or production collision. No fresh-world gameplay, performance, streaming or broad-suite acceptance is claimed. No original issue is closed. Production source and shader hashes are unchanged and recorded alongside all study fixtures and captures in source-hashes.json.
