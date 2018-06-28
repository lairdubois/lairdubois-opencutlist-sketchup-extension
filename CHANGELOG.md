CHANGELOG
=========

This changelog references the relevant changes (bug and security fixes) done
in 1.x and 0.x versions.

* 1.5.1 (DEV)

  * Fix settings storage
  * Change startup file structure 
  
* 1.5.0 (2018-06-25)

  * Added bin packing interface for material of type *Sheet good*
  * Added 2D bin packing library
  * Fixed conversion to local units. Input fields recognize other length units than model units.

* 1.4.2 (2018-06-06)

  * Improved layer visibility management in component faces detection

* 1.4.1 (2018-04-09)

  * Fixed cutlist volume summary
  * Added instance identical names count

* 1.4.0 (2018-04-01)

  * Added new material type : *Dimensional*
  * Added "*Highlight part in model*" button in part's row and edit modal
  * Added "*Edit 'XXX' material*" button in cutlist's group context menu
  * Added unit options observer
  * Added display of length unit in cutlist header
  * cutlist options are stored into model attributes (and SU defaults). It permits to keep cutlist option inside the SKP file.

* 1.3.0 (2018-03-16)

  * Added dynamic components support !
  * Added instance names (if present) in cutlist part rows
  * Fixed part size calculation when a component contains multiples child groups
  * Excluded _always_face_camera_ components from cutlist
  * Treat _cuts_opening_ components has groups
  * Add CHANGELOG link in about tab

* 1.2.3 (2018-03-12)

  * Added dimension column order strategy option in cutlist tab

* 1.2.2 (2017-12-15)

  * Fixed material name update bug on SU 2018

* 1.2.1 (2017-09-30)

  * Added 'Import', 'Export' material to .skm files capabilities
  * Added 'Remove' button on material panel

* 1.2.0 (2017-06-09)

  * Added 'Save part numbers' feature
  * Added 'generated at' on cutlist print
  * Added model, selection and materials observers
  * Added option to save material cutlist defaults manually
  * Added export options
  * Sanitized length values in cutlist export by removing the ~

* 1.1.1 (2017-04-17)

  * Fixed cutlist export bug when export path contains spaces
  * Fixed cutlist export dimensions improvements
  * Removed "x" before quantity in cutlist
  * Sketchup 2014 compatible

* 1.1.0 (2017-04-14)

  * Added cutlist export to CSV
  * Added cumulable feature on parts
  * Added orientation locked on axis on parts

* 1.0.1 (2017-04-11)

  * I18n loading bugfix

* 1.0.0 (2017-04-11)

  * Added ruby access to i18n files
  * Added SU menus to open tabs
  * Switched to 1.0 release

---

* 0.4.6 (2017-04-09)

  * Saving Dialog's size (SU 17 only)
  * Added sticky tab header

* 0.4.5 (2017-01-14)

  * Cutlist part_order_strategy option
  * Cutlist hide_raw_dimensions option
  * Cutlist hide_final_dimensions option
  * Cutlist hide_untyped_material_dimensions option
  * Cutlist hidden_group_ids
  * Cutlist edit groups
  * Materials improve std_thickness input field
  * i18n statically loaded into html to avoid dynamic loading file on runtime (not allowed on all platforms)

* 0.4.4 (2017-01-05)

  * English translation (thanks to @mobilarte)
  * German translation (thanks to @mobilarte)
  * Replace JS localstorage by SU defaults
  * Improve JS <-> Ruby command pipeline
  * cutlist materials origins improvements
  * cutlist auto_orient option
  * cutlist smart_material option
  * cutlist options help popovers
  * cutlist summary no-print setting
  * Add Markdown support in i18n files

* 0.4.3 (2016-12-28)

  * cutlist inherited and child materials
  * I18n support
  * UI improvements

* 0.4.2 (2016-12-18)

  * Cutlist considers all components that contains faces. Not only leaf components.
  * Cutlist area and volume summary bugfix

* 0.4.1 (2016-12-16)

  * cutlist options bugfix
  * compute_faces_bounds now considers groups
  * Add no hard wood material warning in cutlist
  * Edit part name and material from cut list
  * View part thumbnails
  * UI improvements
  * JS <> Ruby exchange protocol rewritten

* 0.4.0 (2016-12-14)

  * New 'Materials' module
  * Ability to manage option on each material
  * cutlist UI improvements

* 0.3.4

  * cutlist ignore flat components
  * Ruby > JS call encode parameter to accept any chars

* 0.3.3 (2016-12-08)

  * Standard thickness option
  * Standard thickness check
  * Cut list options modal improvements

* 0.3.2 (2016-12-07)

  * Add "piece number sequence by group" in cut list options
  * Add "piece number with letter" in cut list options
  * Add cutlist summary
  * cutlist generate errors and warnings
  * cutlist options improvements
  * UI improvements
  * Save options to localStore

* 0.3.1 (2016-12-06)

  * Bug fix : cutlist generate fail on Windows after model save
  * Bug fix : Hide / Show cutlist group fail on SU prior 2017
  * Uses JS localStorage to save user settings
  * cutlist : continuous pieces code increment

* 0.3.0 (2016-12-05)

  * Bug fix : Sketchup 2016 dialog display on PC
  * OS detection
