# # Takana
#
# This is the annotated source code for [Takana](http://usetakana.com/), an
# Scss & CSS live editor plugin for Mac OS X. See the [homepage](http://usetakana.com) 
# for information on installation and usage.
# 
# The annotated source HTML is generated by [Docco](http://jashkenas.github.com/docco/).

# ## Table of contents
module.exports =

  # The [browser](browser/index.html) module manages the communication with the web browser
  browser:    require './browser'
    
  # The [Client](client.html) class provides a way for external processes to communicate with the backend.
  Client:     require './client'

  # The [editor](editor/index.html) module manages the communication with the text editor
  editor:     require './editor'

  # The support module provides various helper functions
  helpers:    require './support/support'

  # The [renderer](renderer/index.html) module provides wrappers around supported compilers
  renderer:   require './renderer'

  # The [Server](server.html) class runs the http and socket servers. It is the **main entry point** to Takana.
  Server:     require './server'

  # The [watcher](watcher/index.html) module maintains a model of the filesystem and the editor buffer
  watcher:    require './watcher'
