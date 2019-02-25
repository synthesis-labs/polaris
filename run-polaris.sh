docker run --rm -it \
  -v "$HOME"/.ssh:/root/.ssh:rw \
  -v "$HOME"/.aws:/root/.aws:ro \
  -v "$HOME"/.kube:/root/.kube:rw \
  -v "$(pwd)":/workdir \
  -w /workdir \
  --env-file environment \
  webstar34/polaris:1.0.0 bash -c '/workdir/create-polaris.sh'
