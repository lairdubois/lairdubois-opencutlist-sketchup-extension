CHANGELOG
=========

This changelog references the relevant changes (bug and security fixes) done
in 0.x versions.

* 0.4.6

  * Saving Dialog's size

* 0.4.5 (2017-01-14)

  * Cutlist part_order_strategy option
  * Cutlist hide_raw_dimensions option
  * Cutlist hide_final_dimensions option
  * Cutlist hide_untyped_material_dimensions option
  * Cutlist hidden_group_ids
  * Cutlist edit groups
  * Materials improve std_thickness input field
  * i18n staticly loaded in html to avoid dynamic loading file on runtine (not allowed on all platforms)
  
* 0.4.4 (2017-01-05)

  * English translation (thanks to @mobilarte)
  * German translation (thanks to @mobilarte)
  * Replace JS localstorage by SU defaults
  * Improve JS <-> Ruby command pipeline
  * Cutlist materials origins improvements
  * Cutlist auto_orient option
  * Cutlist smart_material option
  * Cutlist options help popovers
  * Cutlist summary no-print setting
  * Add Markdown support in i18n files

* 0.4.3 (2016-12-28)

  * Cutlist inherited and child materials
  * I18n support
  * UI improvements
  
* 0.4.2 (2016-12-18)

  * Cutlist considere all components that contains faces. Not only leaf components.
  * Cutlist area and volume summary bugfix
  
* 0.4.1 (2016-12-16)

  * Cutlist options bugfix
  * compute_faces_bounds now considers groups
  * Add no hard wood material warning in cutlist
  * Edit part name and material from cut list
  * View part thumbnails
  * UI improvements
  * JS <> Ruby exchange protocol rewrited

* 0.4.0 (2016-12-14)

  * New 'Materials' module
  * Ability to manage option on each material
  * Cutlist UI improvements

* 0.3.4

  * Cutlist ignore flat components
  * Ruby > JS call encode parameter to accept any chars

* 0.3.3 (2016-12-08)

  * Standard thickness option
  * Standard thickness check
  * Cut list options modal improvements

* 0.3.2 (2016-12-07)

  * Add "piece number sequence by group" in cut list options
  * Add "piece number with letter" in cut list options
  * Add cutlist summary
  * Cutlist generate errors and warnings
  * Cutlist options improvements
  * UI improvements
  * Save options to localStore

* 0.3.1 (2016-12-06)

  * Bug fix : Cutlist generate fail on Windows after model save
  * Bug fix : Hide / Show cutlist group fail on SU prior 2017
  * Uses JS localStorage to save user settings
  * Cutlist : continuous pieces code increment

* 0.3.0 (2016-12-05)

  * Bug fix : Sketchup 2016 dialog display on PC
  * OS detection

