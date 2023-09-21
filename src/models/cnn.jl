using Flux, MLUtils

function make_cnn(size::Tuple, channels)
  @assert size[1] == size[2]
  s = size[1]

  Chain(
    Conv((3, 3), channels => 8, relu),
    Conv((3, 3), 8 => 16, relu),
    Conv((3, 3), 16 => 16, relu),
    MLUtils.flatten,
    Dense(16*(s-6)^2 => 128, relu),
    Dense(128 => 5, tanh)
  )
end