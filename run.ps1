# Stop & remove old container
docker stop gehu50_container
docker rm gehu50_container

$workspacePath = Resolve-Path ./workspaces
docker run -it --rm --privileged `
    --name gehu50_container `
    -p 8443:8443 `
    -v "${workspacePath}:/workspaces" `
    -v "//var/run/docker.sock:/var/run/docker.sock" `
    container

