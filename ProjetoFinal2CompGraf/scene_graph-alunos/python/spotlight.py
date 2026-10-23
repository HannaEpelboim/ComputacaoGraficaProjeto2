from __future__ import annotations

import math
from typing import Any

import graphics_math as gm

from light import Light


class SpotLight(Light):

    def __init__ (self, x: float, y: float, z: float,
                  dx: float, dy: float, dz: float,
                  angle: float = 30.0, exponent: float = 8.0,
                  space: str = "world", **values: Any) -> None:
      Light.__init__(self, space, **values)
      self.set_position(x, y, z)
      self.set_direction(dx, dy, dz)
      self.set_angle(angle)
      self.set_exponent(exponent)

    def set_position (self, x: float, y: float, z: float) -> None:
      self.set("light_position", gm.vec4(x,y,z,1.0))

    def set_direction (self, x: float, y: float, z: float) -> None:
      self.set("light_direction", gm.normalize(gm.vec3(x,y,z)))

    def set_angle (self, degrees: float) -> None:
      self.set("light_cos_cutoff", math.cos(math.radians(degrees)))

    def set_exponent (self, exponent: float) -> None:
      self.set("light_exponent", exponent)

    def map (self, matrix: gm.Mat4) -> dict[str, Any]:
      position = self.get("light_position")
      d = self.get("light_direction")
      direction = (matrix @ gm.vec4(d[0], d[1], d[2], 0.0))[:3]
      return {
        "light_position": matrix @ position,
        "light_direction": gm.normalize(direction),
      }
