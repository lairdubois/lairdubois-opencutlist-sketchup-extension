import ezdxf
from ezdxf import bbox

filename = "bin_001"

doc = ezdxf.readfile(filename + ".dxf")
msp = doc.modelspace()
extents = bbox.extents(msp)

print(extents.extmin)  # Point min (x, y, z)
print(extents.extmax)  # Point max (x, y, z)

extmin = doc.header.get("$EXTMIN")
extmax = doc.header.get("$EXTMAX")

if extmin and extmax and extmin[0] < extmax[0]:
    # bounding box valide
    print(f"Model space : {extmin} → {extmax}")
else:
    print("Invalid model space bounding box")

pextmin = doc.header.get("$PEXTMIN")
pextmax = doc.header.get("$PEXTMAX")

if pextmin and pextmax and pextmin[0] < pextmax[0]:
    # bounding box valide
    print(f"Paper space : {pextmin} → {pextmax}")
else:
    print("Paper space empty or invalid")

doc.saveas(filename + "_ezdxf.dxf")