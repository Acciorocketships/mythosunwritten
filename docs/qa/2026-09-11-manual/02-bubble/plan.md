# Circular visibility bubble

The current radius is measured in world metres, so it occupies only a small part
of the tactical viewport. Two height masks remove its lower portion. Keeping
those masks while enlarging the radius would preserve the reported flat cutoff.

The selected approach derives the cone radius from the camera projection and a
50%-of-screen-width diameter. Coverage is circular in projection; it keeps the
finite camera-to-character extent. The lower projected-height mask is removed.
Nearby upward-facing support surfaces are exempted around the physical feet,
independently of the smoothed visual focus. This applies to native floors,
terraces and sloping terrain using their actual surface normal, rather than
exempting an entire merged terrain/building batch.

First verify an actual rendered lower-half wall probe and a nearby floor probe,
then compare all four photo pins plus nearby angles. Deliberately check raised
lawns, stairs, ground beside walls and alternate viewport aspect ratios. Reject
any candidate that opens the ground underfoot or restores a flat screen cutoff.
