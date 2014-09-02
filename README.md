🐳 pool 🐳
===

The simplest proxy service to access your Dockernized webapps by Git commit-id.

You can build and run your web application as a Docker container just to access
`http://<git-commit-id>.pool.dev` for example.

<p align="center">
<img src="https://raw.githubusercontent.com/wiki/mookjp/pool/images/architecture.png" width="600"/>
</p>


## Requirements

### Vagrant plugin

Need to install [vagrant dns plugin](https://github.com/BerlinVagrant/vagrant-dns). Just run:

> $ vagrant plugin install vagrant-dns

## Setup

Set the configration for dns first:

> $ vagrant dns --install

> $ vagrant dns --start

then run:

> $ vagrant up

Vagrantfile has dns settings for this development environment.
You can access your Docker container just to go `http://<git-commit-id>.pool.dev`.

## How it works

This proxy accesses your Git repository with commit id.
Then checkout it with Dockerfile. Dockerfile should be on the root of the
repository. After checkout files, the container will be built by the Dockerfile
and port is linked with front automatically. All you can do is just to access
`http://<git-commit-id>.pool.dev`.

pool consists of two module; proxy hook and container builder.

`handlers/hook.rb` handles HTTP request as proxy. This is a hook script of
[matsumoto-r/mod_mruby](https://github.com/matsumoto-r/mod_mruby).
It forwards port which Docker container was assigned by Git-commit-id.

If there's no container which corresponds to Git-commit-id, `build_server.rb` works to
build Docker image then runs it.
`build_server.rb` sends build log so that you can confirm the status of build process
while waiting.

## Contributors:

Patches contributed by [great developers](https://github.com/mookjp/pool/contributors).

