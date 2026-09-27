"""Build cloud-free sky faces: cyan horizon fading to pale sky within 10 degrees."""
import math
from pathlib import Path
import struct
import zlib

out = Path(__file__).resolve().parent.parent / 'assets/sky'
out.mkdir(parents=True, exist_ok=True)
def write(name, sample):
    n = 512
    raw = b''.join(b'\0' + bytes(sample(y, n)) * n for y in range(n))
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    (out / name).write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>2I5B', n,n,8,2,0,0,0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
def side(y, n):
    elevation = math.atan(1 - 2 * (y + .5) / n)
    t = max(0, min(1, elevation / math.radians(10)))
    return tuple(round(a + (b-a)*t) for a,b in zip((12,222,237),(190,253,255)))
write('side.png', side)
write('top.png', lambda y,n: (190,253,255))
write('bottom.png', lambda y,n: (12,222,237))
