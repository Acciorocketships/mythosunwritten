extends GutTest

func test_public_posts_keep_native_width_and_complete_support_height():
 var catalog := EnvironmentCatalog.load_default()
 var kit := SuntailBuildingKit.create()
 KitSubstitution.prepare(catalog,kit)
 var source := catalog.descriptor(&"sfv.deck.pillar.001").measured_aabb
 var target := catalog.descriptor(kit.asset(&"post.timber")).measured_aabb
 var fit: Dictionary = KitSubstitution._fits[&"sfv.deck.pillar.001"]
 assert_eq(fit.tiles.size(),1,"A support is one continuous post, not stacked short tiles")
 var bounds: AABB = fit.tiles[0] * target
 assert_true(source.grow(.00001).encloses(bounds),"Slimmer art stays inside the proved support envelope")
 assert_almost_eq(bounds.position.y,source.position.y,.00001,"Foot retains its bearing")
 assert_almost_eq(bounds.end.y,source.end.y,.00001,"Head still bears the upper floor")
 assert_almost_eq(bounds.get_center().x,source.get_center().x,.00001)
 assert_almost_eq(bounds.get_center().z,source.get_center().z,.00001)
 assert_almost_eq(bounds.size.x*VillageWorldScale.HORIZONTAL_SCALE,
  target.size.x*VillageWorldScale.KIT_WORLD_SCALE,.00001,"Use the house kit's post width")
 assert_almost_eq(bounds.size.z*VillageWorldScale.HORIZONTAL_SCALE,
  target.size.z*VillageWorldScale.KIT_WORLD_SCALE,.00001,"Legacy depth must not stretch a square post")

func test_substituted_post_retains_collision_and_identity():
 var catalog := EnvironmentCatalog.load_default()
 var kit := SuntailBuildingKit.create()
 KitSubstitution.prepare(catalog,kit)
 var source := EnvironmentInstancePayload.new()
 source.add(&"sfv.deck.pillar.001",Transform3D(Basis(Vector3.UP,PI*.5),Vector3(3,6,9)),Color.WHITE,&"support.example",true)
 var result := KitSubstitution.apply(source)
 assert_eq(result.instance_count,1)
 var batch: Dictionary = result.batches[kit.asset(&"post.timber")]
 assert_eq(batch.ids[0],&"support.example")
 assert_true(batch.collision_enabled[0],"Width repair must not disable physical support collision")
