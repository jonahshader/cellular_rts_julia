using Reexport

@reexport using CoherentNoise
@reexport using LinearAlgebra
@reexport using Images
@reexport using Match

const Pos = Vector{Int64}

# TODO: combine UnitType and Unit maybe. 
abstract type UnitType end
struct GI <: UnitType end
struct Miner <: UnitType end

get_color(_::GI) = RGB(0f0, 0f0, 1f0)
get_color(_::Miner) = RGB(0.3f0, 0.7f0, 0.2f0)

abstract type TileType end
struct Grass <: TileType end
struct Tree <: TileType end
struct Point <: TileType end

get_color(_::Grass) = RGB(0.3f0, 1f0, 0.3f0)
get_color(_::Tree) = RGB(0f0, 0.5f0, 0f0)
get_color(_::Point) = RGB(1f0, 1f0, 0f0)

get_color(_) = RGB(0f0, 0f0, 0f0)

mutable struct Unit
    type::UnitType
    position::Pos
    selected::Bool
end

mutable struct World
    move_reserve_count::Matrix{UInt8}
    a_units::Vector{Unit}
    b_units::Vector{Unit}
    ore_field::Matrix{UInt8}
    ore_emitters::Vector{Pos}
    terrain::Matrix{TileType}
    age::Int64
end

mutable struct WorldGen
    main_density::Function
    noise_density::Function
    spawn_radius::Float32
    size::Vector{Int32}
    exit_center::Pos
    spatial_scale::Float32
    origin::Vector{Float32}
end

sample_to_mat(width, height, sample, scale=0.01f0) =
    [sample(x * scale, y * scale) for x in 0:(width-1), y in 0:(height-1)]

sample_to_trees(width, height, sample, spatial_scale=0.01f0, vertical_offset=0f0, noise_scale=0.25f0) = 
    (sample_to_mat(width, height, sample, spatial_scale) .+ vertical_offset) .> (randn(width, height) .* noise_scale)

is_in_round_radius(pos, size, radius) = norm(pos .- (size .÷ 2) .- 1) < radius

is_in_square_radius(pos, size, radius) = max(abs.(pos .- (size .÷ 2) .- 1)...) < radius


function make_world_gen(size::Vector = [15, 15], spawn_radius = 3)
    main_sampler = billow_fractal_2d()
    noise_sampler = value_2d()

    main_fun(pos) = sample(main_sampler, pos...)
    noise_fun(pos) = sample(noise_sampler, pos...)

    exit_center = [Int32(x) for x in rand(UInt16, 2) .% size] .- (size .÷ 2)

    if exit_center[1] < spawn_radius && exit_center[1] > -spawn_radius
        if exit_center[1] > 0
            exit_center[1] = spawn_radius
        else
            exit_center[1] = -spawn_radius
        end
    end

    if exit_center[2] < spawn_radius && exit_center[2] > -spawn_radius
        if exit_center[2] > 0
            exit_center[2] = spawn_radius
        else
            exit_center[2] = -spawn_radius
        end
    end

    exit_center .+= (size .÷ 2) .+ 1

    # exit_center[1] = clamp(exit_center[1], 2, width-1)
    # exit_center[2] = clamp(exit_center[2], 2, height-1)

    exit_center .= clamp.(exit_center, 2, size)

    return WorldGen(main_fun, noise_fun, spawn_radius, size, exit_center, 0.1f0, rand(Float32, 2) .* 0.5f0)
end

# function demo_tree(;size=32, spatial_scale=0.05f0, vertical_offset=0f0, noise_scale=0.2f0)
#     density = make_wall_density(size, size)
#     sample_to_trees(size, size, density, spatial_scale, vertical_offset, noise_scale) |> heatmap
# end

sample_main(world_gen::WorldGen, pos::Pos) = world_gen.main_density((pos .* world_gen.spatial_scale) .+ world_gen.origin)

sample_noise(world_gen::WorldGen, pos::Pos) = world_gen.noise_density(pos .* world_gen.spatial_scale .* 32 .+ world_gen.origin)

is_tree(world_gen::WorldGen, pos::Pos) = sample_main(world_gen, pos) + .1f0 > sample_noise(world_gen, pos .+ 32) * .5f0

is_spawn(world_gen::WorldGen, pos::Pos) = is_in_square_radius(pos, world_gen.size, world_gen.spawn_radius)

is_gi(world_gen::WorldGen, pos::Pos) = is_in_round_radius(pos, world_gen.size, world_gen.spawn_radius * 0.75f0)

is_point(world_gen::WorldGen, pos::Pos) = !is_in_square_radius(pos, world_gen.size, world_gen.spawn_radius * 2f0)
# is_in is one of the above
get_all_pos(world_gen::WorldGen, is_in::Function) = [[x, y] for x in 1:world_gen.size[1] for y in 1:world_gen.size[2] if is_in(world_gen, [x, y])]

pos_to_unit(pos::Pos, T)::Unit = Unit(T, pos, false)

# TODO: check type stability, performance implications
make_pos_to_type(type) = pos -> pos_to_unit(pos, type())
# test with: 
# c = cellular_rts
# wgen = c.make_world_gen()
# c.get_all_pos(wgen, c.is_gi) .|> c.make_pos_to_type(c.Miner)

pos_to_gi(pos::Pos) = pos_to_unit(pos, GI())

function make_tile(world_gen::WorldGen, pos::Pos)::TileType
    if is_spawn(world_gen, pos)
        return Grass()
    elseif is_tree(world_gen, pos)
        return Tree()
    elseif is_point(world_gen, pos)
        return Point()
    else
        return Grass()
    end
end

function render_unit!(mat::Matrix{Bool}, unit::Unit)
    mat[unit.position...] = true
    nothing
end

function render_units(units::Vector{Unit}, size::Tuple)::AbstractMatrix{Bool}
    mat = zeros(Bool, size...)
    for unit in units
        render_unit!(mat, unit)
    end
    mat
end



make_terrain(world_gen::WorldGen) = [make_tile(world_gen, [x, y]) for x in 1:world_gen.size[1], y in 1:world_gen.size[2]]

test_terrain() = make_world_gen() |> make_terrain .|> get_color



function World(; size=15, world_gen::WorldGen=make_world_gen([size, size]))
    World(
        zeros(UInt8, size, size),
        Vector{Unit}(),
        Vector{Unit}(),
        zeros(UInt8, size, size),
        Vector{Pos}(),
        make_terrain(world_gen),
        0
    )
end