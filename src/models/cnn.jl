using Flux, MLUtils

function make_cnn(size::Tuple, channels, outputs)
  @assert size[1] == size[2]
  s = size[1]

  Chain(
    Conv((3, 3), channels => 8, relu),
    Conv((3, 3), 8 => 16, relu),
    Conv((3, 3), 16 => 4, relu),
    MLUtils.flatten,
    Dense(4*(s-6)^2 => 128, relu),
    Dense(128 => outputs, tanh)
  )
end

function make_cnn_temp()
  make_cnn((15, 15), MAX_LAYERS, 5)
end