TAG="${SETTINGS[tag]}"
info "Pushing Docker image: $TAG"
exec docker push "$TAG"
