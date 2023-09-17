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

# get_color(unknown) = RGB(0f0, 0f0, 0f0)
function get_color(unknown)
    println(typeof(unknown))
    RGB(0f0, 0f0, 0f0)
end

get_color(_::GI) = RGB(0f0, 0f0, 1f0)
get_color(_::Miner) = RGB(0.3f0, 0.7f0, 0.2f0)

abstract type TileType end
struct Grass <: TileType end
struct Tree <: TileType end
struct Point <: TileType end

get_color(_::Grass) = RGB(0.3f0, 1f0, 0.3f0)
get_color(_::Tree) = RGB(0f0, 0.5f0, 0f0)
get_color(_::Point) = RGB(1f0, 1f0, 0f0)

solid(_) = false
solid(_::Grass) = false
solid(_::Tree) = true
solid(_::Point) = false



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
# using cellular_rts
# c = cellular_rts
# wgen = c.make_world_gen()
# c.get_all_pos(wgen, c.is_gi) .|> c.make_pos_to_type(c.Miner)

const pos_to_gi = make_pos_to_type(GI)
const pos_to_miner = make_pos_to_type(Miner)

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

function plot_units(units::Vector{Unit}, size::Tuple)::AbstractMatrix{Bool}
    mat = zeros(Bool, size...)
    for unit in units
        mat[unit.position...] = true
    end
    mat
end

function render_units(units::Vector{Unit}, size::Tuple)::AbstractMatrix{RGB}
    mat = zeros(RGB, size...)
    for unit in units
        mat[unit.position...] = get_color(unit)
    end
    mat
end

function render_units!(img, units::Vector{Unit})
    for unit in units
        img[unit.position...] = get_color(unit.type)
    end
    nothing
end


make_terrain(world_gen::WorldGen) = [make_tile(world_gen, [x, y]) for x in 1:world_gen.size[1], y in 1:world_gen.size[2]]

test_terrain() = make_world_gen() |> make_terrain .|> get_color

function render_world(world::World)
    img = world.terrain .|> get_color
    render_units!(img, world.a_units)
    render_units!(img, world.b_units)
    img
end

function World(; size=15, world_gen::WorldGen=make_world_gen([size, size]))
    a_units = pos_to_gi.(get_all_pos(world_gen, is_gi))
    
    World(
        zeros(UInt8, size, size),
        a_units,
        Vector{Unit}(),
        zeros(UInt8, size, size),
        Vector{Pos}(),
        make_terrain(world_gen),
        0
    )
end

function target_pos(unit::Unit, dir::Pos, world_size::Tuple, occupancy::AbstractMatrix{Bool})
    tpos = [unit.position...]
    if unit.selected
        tpos .+= dir
    end
    tpos[1] = clamp(tpos[1], 1:world_size[1])
    tpos[2] = clamp(tpos[2], 1:world_size[2])
    if occupancy[tpos...]
        return [unit.position...]
    else
        return tpos
    end
    
end

function action_vec_to_dir(action)
    discrete_action = argmax(action)
    dir::Pos = [0, 0]

    if discrete_action != 1
        if discrete_action == 2
            dir[1] = -1
        elseif discrete_action == 3
            dir[2] = 1
        elseif discrete_action == 4
            dir[1] = 1
        else discrete_action == 5
            dir[2] = -1
        end
    end
    dir
end

# action lenght = 10
function act!(world::World, action::Vector{Float32})
    s = size(world.terrain)
    select_min = min.(1f0 .+ min.(action[1:2], action[3:4]) .* s[1], s[1]) .|> round .|> Int64
    select_max = min.(1f0 .+ max.(action[1:2], action[3:4]) .* s[2], s[2]) .|> round .|> Int64
    
    dir = action_vec_to_dir(action[5:9])
    change_selection = action[10] > 0.5f0

    act!(world, select_min, select_max, change_selection, dir)
end

function act_always_selected!(world::World, action::Vector{Float32})
    s = size(world.terrain)
    select_min = [1, 1]
    select_max = [s[1], s[2]]
    discrete_action = argmax(action[1:5])
    
end


# action must be length 10
function act!(world::World, select_min, select_max, change_selection, dir)
    # TODO: replace for loops with maps or something
    s = size(world.terrain)

    if change_selection
        # todo: iterate units, change selection
        for unit in world.a_units
            if reduce(&, select_min .<= unit.position .<= select_max)
                unit.selected = true
            else
                unit.selected = false
            end
        end
    end

    # clear move_reserve_count
    fill!(world.move_reserve_count, 0)

    # build an occupancy map
    occupancy = solid.(world.terrain)

    for unit in world.a_units
        @assert occupancy[unit.position...] == false
        occupancy[unit.position...] = true
    end

    # TODO make more julian
    if dir[1] != 0 || dir[2] != 0
        # add to move_reserve_count
        # all units do this even if they don't want to move
        for unit in world.a_units
            tpos = target_pos(unit, dir, s, occupancy)
            # increment reserve count for desired pos
            world.move_reserve_count[tpos...] += 1
        end

        # move units
        for unit in world.a_units
            tpos = target_pos(unit, dir, s, occupancy)
            if world.move_reserve_count[tpos...] == 1
                unit.position .= tpos
            end
        end
    end

    # collect points
    points = 0

    for unit in world.a_units
        # TODO: maybe try comparison against Point() instead
        if world.terrain[unit.position...] == Point()
            points += 1
            world.terrain[unit.position...] = Grass()
        end

    end

    world.age += 1
    
    points
end
