Birthdoc App
============

Example REY app that lets users share in the Reputation Network their birth date, as extracted from their ID.

Available live at http://rey-example-birthdoc.herokuapp.com.

Requirements
------------

You'll need [rey-cli](http://github.com/reputation-network/rey-cli) installed in your system.

Usage
-----

Simply start the app with:

    docker-compose up

Then, you'll need to register the app's manifest on the running blockchain node with:

    rey-cli dev cmd publish-manifest 0x88032398beab20017e61064af3c7c8bd38f4c968 http://localhost:8000/manifest
