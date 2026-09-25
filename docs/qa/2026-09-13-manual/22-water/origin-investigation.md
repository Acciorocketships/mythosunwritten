# P01 water cutoff — open

The current complete-world P01 capture still has the original straight water
edge. Native opaque controls show chunk (0,-1) has zero water triangles while
(-1,-1), (-1,0), and (0,0) are wet beside it.

The red regression compares five identical world positions through all four
contexts. The three neighboring contexts return 7.9499998 m over 0 m ground;
(0,-1) returns dry. It fails five ownership assertions (20/25 pass), in
130.149 seconds. This is field disagreement, not missing shader animation.

The initiating sources differ and therefore choose different rectangular
hydraulic domains. At (0,-1), the domain ends just 11.24 m north of the origin;
its boundary acts as an outlet. Neighboring domains extend roughly 1.9 km
farther north and retain water at the same point. Every domain includes the
complete bounds of its initiating rivers and rediscovers intersecting sources,
but that does not make the hydraulic answer independent of the requesting
chunk. No repair is accepted or implemented for this issue yet.

See origin-red.log and domains.log. The P39 wave-clearance candidate is a
separate change and cannot resolve this static field inconsistency.

A separate lazy ground survey follows the complete connected component below
7.95 m from the origin, without using any hydraulic rectangle as a boundary.
It closes after 12,561 wet lattice points with 592 rim points and 26 terrain
regions. Its extent is (-210,-978) to (258,258), confirming that the (0,-1)
calculation edge at z=12 cuts this basin. This establishes incomplete domain
coverage; it does not yet determine a globally authoritative water head or
justify treating the temporary boundary as a dam. See origin-basin.json.
