include("ga.jl")

unzip(a) = map(x->getfield.(a, x), fieldnames(eltype(a)))

# TODO: make this more julian. shouldn't need to take in act_fun since we can redefine act! for different types
function eval_batch_step!(envs, model)
  states = plot_all.(envs)
  # turn vector of 3d arrays into 4d array
  states = reduce((x, y) -> cat(x, y, dims=4), states)

  action_vecs = model(states)

  rewards, dones = act_always_selected!.(envs, eachslice(action_vecs, dims=2))

  # println(sum(dones .== true))

  return sum(Float32.(rewards)) / length(rewards), reduce(&, dones)
end


function eval_model(model, make_env, batches)
  envs = [make_env() for _ in 1:batches]

  done = false
  total_reward = 0f0
  while done == false
    reward, done = eval_batch_step!(envs, model)
    total_reward += reward
    
    println(reward)
  end

  return total_reward
end