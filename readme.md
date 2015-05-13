buildScript
===========

Script use to rebuild the meta data of [api](https://github.com/cdnjs/cdnjs#api) and [website](https://cdnjs.com/), and then deploy them.

## Repositories
* **cdnjs**, the main repo we are working on
* **cdnjsmaster**, the clean repo be used to build
* **new-website**, the website and api repo

## Branches and remotes

### Branches
* **cdnjsmaster** should stay on master, this repo is setup for build process only.
* **new-website** should have two branches, one is **master**, for the real codes, another one will be **meta**, **meta** beanch will save additional meta data the we'll use for website and api, but not real codes.

### Remotes
 * **cdnjsmaster** should have a **local** remote, which will points to **cdnjs**, we want the most objects will be fetched locally.
 * **new-website** should have 3 remotes, **origin** will point to the repo on GitHub, and the others will be **heroku** and **heroku2**, which will point to the api and website project on heroku.
