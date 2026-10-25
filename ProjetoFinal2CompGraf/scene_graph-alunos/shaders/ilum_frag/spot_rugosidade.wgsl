struct Matrix {
  vertex: mat4x4<f32>,
  normal: mat4x4<f32>,
}
@group(1) @binding(0) var<storage, read> matrix: array<Matrix>;

struct Global {
  projection: mat4x4<f32>,   // espaco de iluminacao -> NDC
  light_ambient: vec3<f32>,
  light_diffuse: vec3<f32>,
  light_specular: vec3<f32>,
  light_position: vec4<f32>,
  light_direction: vec3<f32>,
  light_cos_cutoff: f32,
  light_exponent: f32,
  camera_position: vec4<f32>,  // posicao da camera no espaco de iluminacao
}
@group(0) @binding(0) var<uniform> global: Global;

struct Material {
  base_color: vec3<f32>,
  opacity: f32,

  specular_color: vec3<f32>,
  shininess: f32,
}
@group(2) @binding(0) var<uniform> material: Material;

// decal: cor (srgb); normal_texture: mapa de normais (rgba8unorm).
// Objeto sem rugosidade usa um mapa neutro de 1x1 com (0.5,0.5,1.0),
// que decodifica para n = (0,0,1) - a propria normal da superficie.
@group(3) @binding(0) var decal_texture: texture_2d<f32>;
@group(3) @binding(1) var normal_texture: texture_2d<f32>;
@group(3) @binding(2) var tex_sampler: sampler;

struct VertexOutput {
  @builtin(position) clip_position: vec4<f32>,
  @location(0) position: vec3<f32>,   // posicao no espaco de iluminacao (para o spot)
  @location(1) light: vec3<f32>,      // l no espaco tangente
  @location(2) view: vec3<f32>,       // v no espaco tangente
  @location(3) texcoord: vec2<f32>,
}

@vertex
fn vs_main (@builtin(instance_index) instance_index: u32,
            @location(0) coord: vec3<f32>,
            @location(1) normal: vec3<f32>,
            @location(2) tangent: vec3<f32>,
            @location(3) texcoord: vec2<f32>) -> VertexOutput {
  let m = matrix[instance_index];
  var out: VertexOutput;
  let p = (m.vertex * vec4<f32>(coord, 1.0)).xyz;

  // base do espaco tangente: t acompanha a superficie (matriz do vertice),
  // n usa a matriz de normais; b = n x t completa a base
  let n = normalize((m.normal * vec4<f32>(normal, 0.0)).xyz);
  var t = normalize((m.vertex * vec4<f32>(tangent, 0.0)).xyz);
  t = normalize(t - dot(t, n) * n);   // garante t perpendicular a n
  let b = cross(n, t);

  let l = normalize(global.light_position.xyz - p);
  let v = normalize(global.camera_position.xyz - p);

  // leva l e v para o espaco tangente: projecao em (t, b, n)
  out.light = vec3<f32>(dot(l, t), dot(l, b), dot(l, n));
  out.view = vec3<f32>(dot(v, t), dot(v, b), dot(v, n));
  out.position = p;
  out.texcoord = texcoord;
  out.clip_position = global.projection * vec4<f32>(p, 1.0);
  return out;
}

@fragment
fn fs_main (in: VertexOutput) -> @location(0) vec4<f32> {
  // normal perturbada lida do mapa: [0,1] -> [-1,1]
  let normal = normalize(2.0 * textureSample(normal_texture, tex_sampler, in.texcoord).rgb - 1.0);
  let light = normalize(in.light);
  let view = normalize(in.view);

  // fator do spot calculado no espaco de iluminacao, como em spot.wgsl:
  // c = -l . sdir ; dentro do cone quando c >= cos(theta)
  let lw = normalize(global.light_position.xyz - in.position);
  let c = dot(-lw, normalize(global.light_direction));
  var kspot = 0.0;
  if (c >= global.light_cos_cutoff) {
    if (global.light_exponent > 0.0) {
      kspot = pow(max(c, 0.0), global.light_exponent);
    } else {
      kspot = 1.0;
    }
  }

  let decal = textureSample(decal_texture, tex_sampler, in.texcoord).rgb;
  let base = material.base_color * decal;

  var color = base * global.light_ambient;
  let ndotl = select(0.0, dot(normal, light), light.z > 0.0);
  if (ndotl > 0.0) {
    color += base * global.light_diffuse * ndotl;
    let refl = normalize(reflect(-light, normal));
    color += material.specular_color * global.light_specular * pow(max(0.0, dot(refl, view)), material.shininess);
  }
  return vec4<f32>(kspot * color, 1.0);
}