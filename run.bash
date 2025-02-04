workspacePath=$(realpath ./workspaces)
docker stop gehu50_container
docker rm gehu50_container

docker run -it --rm \
    --name gehu50_container \
    -p 8443:8443 \
    -v $workspacePath:/workspaces \
    -v /var/run/docker.sock:/var/run/docker.soc \
    -e RepositoryName=1234 \
    container
