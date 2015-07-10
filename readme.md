buildScript
===========

Script use to rebuild the meta data of [api](https://github.com/cdnjs/cdnjs#api) and [website](https://cdnjs.com/), and then deploy them.

Most of the codes will be in `update-website.sh`, `build.sh` is the file we need to execute, and `config.sh` is the file contains the configs.

Take a look at the script, set the path and api key in `config.sh` before use it.

## Repositories
* **cdnjs**, the main repo we are working on
* **cdnjsmaster**, the clean repo be used to build
* **new-website**, the website and api repo

## Branches and remotes

### Branches
* **cdnjsmaster** should stay on master, this repo is setup for build process only.
* **new-website** should have two branches
  * one is **master**, for the real codes
  * another one will be **meta**, **meta** beanch will save additional meta data the we'll use for website and api, but not real codes.

### Remotes
 * **cdnjsmaster** should have two remotes,
   * **origin** will point to the repo on GitHub
     * git@github.com:cdnjs/cdnjs.git
   * **local** will points to the local working **cdnjs**, we want the most objects will be fetched locally.
     * For example: `/home/peter/cdnjs/cdnjs_working`
 * **new-website** should have 3 remotes,
   * **origin** will point to the repo on GitHub
     * git@github.com:cdnjs/new-website.git
   * the others will be **heroku** and **heroku2**, which will point to the api and website project on heroku.
     * git@heroku.com:cdnjs-new-website.git
     * git@heroku.com:cdnjsapi.git
