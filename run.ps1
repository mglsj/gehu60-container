# Stop & remove old container
$containerName = "gehu60_container"
$containerExists = docker ps -a --filter "name=$containerName" --format "{{.Names}}" | Select-String -Pattern $containerName

if ($containerExists) {
    # Remove the container forcefully
    docker rm -f $containerName
} 

$workspacePath = Resolve-Path ./workspaces

docker run -it --rm --privileged `
    --name $containerName `
    -p 8443:8443 `
    -v "${workspacePath}:/workspaces" `
    -v "//var/run/docker.sock:/var/run/docker.sock" `
    -e RepositoryName=1234 `
    container

