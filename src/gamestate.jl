using Reexport

@reexport using CoherentNoise
@reexport using LinearAlgebra
@reexport using Images
@reexport using Match

const Pos = Vector{Int64}

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
    team::Bool
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


function make_world_gen(size::Vector, spawn_radius)
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

# is_point(world_gen::WorldGen, pos::Pos) = sample_noise(world_gen, pos) > 0.125f0
is_point(world_gen::WorldGen, pos::Pos) = !is_in_square_radius(pos, world_gen.size, world_gen.spawn_radius * 2f0)

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

make_terrain(world_gen::WorldGen) = [make_tile(world_gen, [x, y]) for x in 1:world_gen.size[1], y in 1:world_gen.size[2]]

test_terrain() = make_world_gen([15, 15], 3) |> make_terrain .|> get_color


# wall_density is (x, y) -> float
# function World(; width::Integer=32, height::Integer=2, wall_density::WorldGen = make_wall_density(), origin::SVector{2, Float32}=SA_F32[0, 0])
#     # TODO: make better version of sample_to_trees: sample_to_buildings
#     return World(
#         zeros(UInt8, width, height),
#         Vector{Unit}(),
#         Vector{Unit}(),
#         randn(UInt8, width, height),
#         Vector{Pos}(),
#         Matrix{BuildingType}(BuildingType.noone, width, height),
#         origin,
#         0
#     )
# end