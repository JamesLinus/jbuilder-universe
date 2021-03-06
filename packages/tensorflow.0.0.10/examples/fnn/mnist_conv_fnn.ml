open Base
open Float.O_dot
open Tensorflow
open Tensorflow_fnn

let label_count = Mnist_helper.label_count
let image_dim = Mnist_helper.image_dim
let epochs = 2000
let batch_size = 256

let conv2d =
  Fnn.conv2d ~w_init:(`normal 0.1) ~filter:(5, 5) ~strides:(1, 1) ~padding:`same
let max_pool = Fnn.max_pool ~filter:(2, 2) ~strides:(2, 2) ~padding:`same

let () =
  let { Mnist_helper.train_images; train_labels; test_images; test_labels } =
    Mnist_helper.read_files ()
  in
  let input, input_id = Fnn.input ~shape:(D1 image_dim) in
  let model =
    Fnn.reshape input ~shape:(D3 (28, 28, 1))
    |> conv2d ~out_channels:32 ()
    |> max_pool
    |> conv2d ~out_channels:64 ()
    |> max_pool
    |> Fnn.flatten
    |> Fnn.dense ~w_init:(`normal 0.1) 1024
    |> Fnn.relu
    |> Fnn.dense ~w_init:(`normal 0.1) label_count
    |> Fnn.softmax
    |> Fnn.Model.create Float
  in
  Fnn.Model.fit model
    ~loss:(Fnn.Loss.cross_entropy `sum)
    ~optimizer:(Fnn.Optimizer.adam ~learning_rate:1e-4 ())
    ~epochs
    ~batch_size
    ~input_id
    ~xs:train_images
    ~ys:train_labels;
  let test_results = Fnn.Model.predict model [ input_id, test_images ] in
  Stdio.printf "Accuracy: %.2f%%\n%!" (100. *. Mnist_helper.accuracy test_results test_labels)
