// The face model's steps on the graphics card, one value of the output per invocation, in batches of 64 laid out
// over x and then y (a dispatch has at most 65,535 batches a side). Tensors are flat, channel by row by column, one
// picture. `p` holds a step's numbers in the order plan.rs gives them, the first how many values it writes; each
// entry point reads only the bindings it names, so a step binds only those.

@group(0) @binding(0) var<uniform> p: array<vec4<u32>, 4>;
@group(0) @binding(1) var<storage, read> a: array<f32>;
@group(0) @binding(2) var<storage, read> b: array<f32>;
@group(0) @binding(3) var<storage, read> c: array<f32>;
@group(0) @binding(4) var<storage, read_write> out: array<f32>;

fn at(k: u32) -> u32 {
    return p[k / 4u][k % 4u];
}

fn index(id: vec3<u32>, batches: vec3<u32>) -> u32 {
    return id.x + id.y * batches.x * 64u;
}

// a: the input, b: the weights (out channel, in channel of its group, row, column), c: the bias.
// p: n, channels in, height, width, channels out, out height, out width, kernel side, stride, padding, groups.
@compute @workgroup_size(64)
fn conv(@builtin(global_invocation_id) id: vec3<u32>, @builtin(num_workgroups) batches: vec3<u32>) {
    let i = index(id, batches);
    if i >= at(0u) {
        return;
    }
    let h = at(2u);
    let w = at(3u);
    let oh = at(5u);
    let ow = at(6u);
    let k = at(7u);
    let stride = at(8u);
    let pad = at(9u);
    let per = at(1u) / at(10u);
    let column = i % ow;
    let row = (i / ow) % oh;
    let channel = i / (ow * oh);
    let first = (channel / (at(4u) / at(10u))) * per;
    var sum = c[channel];
    for (var inner = 0u; inner < per; inner++) {
        for (var ky = 0u; ky < k; ky++) {
            let y = i32(row * stride + ky) - i32(pad);
            if y < 0 || y >= i32(h) {
                continue;
            }
            for (var kx = 0u; kx < k; kx++) {
                let x = i32(column * stride + kx) - i32(pad);
                if x < 0 || x >= i32(w) {
                    continue;
                }
                sum += a[((first + inner) * h + u32(y)) * w + u32(x)] * b[((channel * per + inner) * k + ky) * k + kx];
            }
        }
    }
    out[i] = sum;
}

// p: n.
@compute @workgroup_size(64)
fn relu(@builtin(global_invocation_id) id: vec3<u32>, @builtin(num_workgroups) batches: vec3<u32>) {
    let i = index(id, batches);
    if i < at(0u) {
        out[i] = max(a[i], 0.0);
    }
}

// p: n.
@compute @workgroup_size(64)
fn sigmoid(@builtin(global_invocation_id) id: vec3<u32>, @builtin(num_workgroups) batches: vec3<u32>) {
    let i = index(id, batches);
    if i < at(0u) {
        out[i] = 1.0 / (1.0 + exp(-a[i]));
    }
}

// a and b of one shape. p: n.
@compute @workgroup_size(64)
fn add(@builtin(global_invocation_id) id: vec3<u32>, @builtin(num_workgroups) batches: vec3<u32>) {
    let i = index(id, batches);
    if i < at(0u) {
        out[i] = a[i] + b[i];
    }
}

// No padding; the window always inside. p: n, height, width, out height, out width, kernel side, stride.
@compute @workgroup_size(64)
fn max_pool(@builtin(global_invocation_id) id: vec3<u32>, @builtin(num_workgroups) batches: vec3<u32>) {
    let i = index(id, batches);
    if i >= at(0u) {
        return;
    }
    let h = at(1u);
    let w = at(2u);
    let oh = at(3u);
    let ow = at(4u);
    let k = at(5u);
    let stride = at(6u);
    let column = i % ow;
    let row = (i / ow) % oh;
    let channel = i / (ow * oh);
    var most = -3.4e38;
    for (var ky = 0u; ky < k; ky++) {
        for (var kx = 0u; kx < k; kx++) {
            most = max(most, a[(channel * h + row * stride + ky) * w + column * stride + kx]);
        }
    }
    out[i] = most;
}

// Nearest, by whole scales: an output cell reads the input's cell at its position divided by the scale, rounded
// down. p: n, height, width, out height, out width, scale down, scale across.
@compute @workgroup_size(64)
fn resize(@builtin(global_invocation_id) id: vec3<u32>, @builtin(num_workgroups) batches: vec3<u32>) {
    let i = index(id, batches);
    if i >= at(0u) {
        return;
    }
    let oh = at(3u);
    let ow = at(4u);
    let column = i % ow;
    let row = (i / ow) % oh;
    let channel = i / (ow * oh);
    out[i] = a[(channel * at(1u) + row / at(5u)) * at(2u) + column / at(6u)];
}

// Four axes. p: n, the output's sides 1 to 3, then per output axis the input's step along it.
@compute @workgroup_size(64)
fn transpose(@builtin(global_invocation_id) id: vec3<u32>, @builtin(num_workgroups) batches: vec3<u32>) {
    let i = index(id, batches);
    if i >= at(0u) {
        return;
    }
    let o3 = i % at(3u);
    let o2 = (i / at(3u)) % at(2u);
    let o1 = (i / (at(3u) * at(2u))) % at(1u);
    let o0 = i / (at(3u) * at(2u) * at(1u));
    out[i] = a[o0 * at(4u) + o1 * at(5u) + o2 * at(6u) + o3 * at(7u)];
}
