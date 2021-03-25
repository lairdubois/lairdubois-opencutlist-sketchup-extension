CHANGELOG
=========

This changelog references the relevant changes (bug and security fixes) done
in 2.x, 1.x and 0.x versions.

* 2.0.1 (WIP)

  * Global and Model preset are now sorted
  
* 2.0.0 (2021-03-23)

  * Added printable **Labels** feature
  * Added printable **Reports** feature
  * Added **Polish** language (thanks to Jarek Ostaszewski and Greg Gregosky)
  * Added **Czech** language (thanks to Radek Rýznar for joining the translators team)
  * Added **Hebrew** language, experimental without RTL interface (thanks to Sergey Isupov for joining the translators team)
  * Added **Arabic** language, experimental without RTL interface (thanks to Soul Issam for joining the translators team)
  * Added **Dutch** language (thanks to Dany Dhondt and Eric Lugtigheid for joining the translators team)
  * Added Hardware material type
  * Added part set for hardware
  * Added part unit price and weight fields for hardware
  * Added part export to skp
  * Added bars and sheets waste's cross display / hide in cutting diagram options
  * Added new 2D bin packing library
  * Added cutting diagram 1D/2D option to render full width diagrams
  * Added cutting diagram 1D/2D option to define the origin corner
  * Added cutting diagram 2D primary cuts
  * Added cutting diagram 2D edge banding infos in part tooltips
  * Added SketchUp 2021 Tag folders compatibility
  * Added custom proposal list of tags in cutlist options
  * Added _tags_ sorter in cutlist options
  * Added _Disable mirrored part detection on this part_ part's property
  * Added comments display on news
  * Added dump and reset global and model presets for debugging
  * Improved import by putting new instances into a group
  * **Inverted** front and back face detection. Front face is not the _Top_ face

* 1.9.10 (2020-12-17)

  * Changed OCL length dimension precision from 0.000000 to 0.000 and adapt it if model length precision is higher
  * Added **Spanish** language (thanks to Leonardo Romero Giménez for joining the translators team)
  * Fixed a bug in 1D packing pertaining to offcuts
  * Fixed a bug highlight part tool when part drawing was in sub group

* 1.9.9 (2020-11-19)

  * Added "News" tab
  * Added "Forum" tab
  * Fixed "Highlight part" tool
  * Improved material attributes default according to unit system
  * Improved thickness and section precision display
  * Improved readability of square feet area dimensions
  * Changed ft³ to FBM (foot, board measure) for Material Solid Wood

* 1.9.8 (2020-10-28)

  * Improved "self-updater" workflow

* 1.9.7 (2020-10-21)

  * Added embedded tutorial's videos
  * Improved "undo" management for a better User Experience :P
  * Minor Fixes and Improvements

* 1.9.6 (2020-10-17)

  * Fixed Ruby 2.7.0 deprecated calls
  * Fixed Layer0 visibility detection
  * Fixed Dimension regex for *X' X X/X'* input format
  * Improved ComponentDefinition and Material uuids management

* 1.9.5 (2020-10-01)

  * Fixed cumulative length or width on folded parts
  * Added **Portuguese** language (thanks to Nayton Sanches Barbosa for joining the translators team)
  * Added sponsor objective display
  * Added cutting diagram (1d and 2d) capability to compute only for selected (in part list) parts
  * Added possibility to add a quantity in cutting diagram 1d and 2d "offcut" field
  * Added public message of backers in sponsor list
  * Added link to tutorials list on GitHub in "More" tab
  * Improved dimension token field input

* 1.9.4 (2020-09-11)

  * Fixed cutting diagrams 2D rotated part dimensions display bug
  * Fixed cutting diagrams crash when using non letter part numbers

* 1.9.3 (2020-08-27)

  * Fixed cutting diagrams 1D bug introduced in 1.9.2

* 1.9.2 (2020-08-27)

  * Fixed cutting size with edge reduction in cutting diagrams
  * Added **Italian** language (thanks to Pierluigi Colombo for joining the translators team)
  * Added part oversize view
  * Added edit part tab memory
  * Added cutting diagram 1d / 2d options tab memory
  * Added textinput reset button
  * Improved russian translation

* 1.9.1 (2020-07-05)

  * Fixed impossible final area
  * Fixed material unique name
  * Fixed IE limitations on url parameter size
  * Improved cutlist part number storage
  * Rollback twig to 1.13.3 for IE compatibility

* 1.9.0 (2020-06-04)

  * Added **Russian** language (thanks to Vladimir Badulya for joining the translators team)
  * Added **self-updater**
  * Added **dimensional cutting diagram** feature (thanks to Kai Schröder, CyberBLN, for code review and fixes)
  * Added flipped part detection  
  * Added 'hit enter' behavior to validate forms in modal dialogs
  * Added part oversize parameters
  * Fixed some New Material modal issues
  * Improved cutlist scroll to first visible group (only if no alert)
  * Improved highlight tool to display part orientation with front and back face
  * Improved obsolete generated (materials, cutlist) management
  * Improved cutlist part numbers storing. Now, it take care of multiple part with the same definition.
  * Replaced 'selection only' warning by displaying this info in header

* 1.8.4 (2020-01-09)

  * Added part "Number" column in cutlist instance export
  * Removed $debug global variable in rchardet lib

* 1.8.3 (2019-12-19)

  * Added Materials order option
  * Cutlist highlight multiple parts improvements
  * Sponsor ad

* 1.8.2 (2019-12-12)

  * Fixed Material name and color form

* 1.8.1 (2019-11-20)

  * Added edge 'copy to all' shortcut
  * Added multiple edition of parts in cutlist
  * Added sponsor tab
  * Added cutting diagram part list display option

* 1.8.0 (2019-10-01)

  * Added edge band material type and management
  * Added new tab to import parts
  * Added cutlist dynamic component names option
  * Added instances list to cutlist export sources
  * Added 'Minimize on highlight' as an option
  * Added create material from materials tab
  * Added 'set current' material from materials tab
  * Added 'Edit part properties' menu item
  * Added 'Edit part axes properties' menu item
  * Export cutlist instance names
  * Show only material display names

* 1.7.1 (2019-06-30)

  * Added missing translations
  * Added material tint capabilities
  * Added part axes management
  * Added 'add unavailable' std dimension to material on cutlist group
  * Added group's material average color in cutlist

* 1.7.0 (2019-06-10)

  * Added cutlist same size part grouping option
  * Added cutlist export source option
  * Added cutlist hide entity names option
  * Added cutlist real area for sheet good part
  * Added cutlist auto orient display
  * Added cutlist part orientation check
  * Added cutlist multiple layers check
  * Added cutlist dimensions help modals
  * Added cutlist part edit tabs
  * Added materials texture rotation feature
  * Added context menu to edit selected part properties from model selection
  * Added "more" leftbar submenu
  * Added new extension icon

* 1.6.3 (2019-05-09)

  * Export cutlist labels
  * New language management improvement
  * Fixed cutlist crash on Sketchup 2014

* 1.6.2 (2019-04-23)

  * Added custom language option in settings
  * Added raw volume in all type of material in cutlist summary
  * Added cutlist "width" separators if first sort order is width on solid wood material parts
  * Fixed Highlight tool bug with simple ComponentInstance children

* 1.6.1 (2019-02-15)

  * Reverted i18next javascript lib for compatibility issues
  * Javascripts string polyfills
  * Fixed some IE 9 issues

* 1.6.0 (2019-02-11)

  * Added Cutlist part's labels
  * Added "*Highlight parts in model*" option on entire cutlist and groups

* 1.5.3 (2018-12-10)

  * Cutlist export now includes part numbers

* 1.5.2 (2018-11-01)

  * Reset imported material UUID

* 1.5.1 (2018-07-18)

  * Fixed settings storage
  * Changed startup file structure
  * Hide cutlist group's raw dimensions if no length or width increase is defined
  * Added persistent material UUID mechanism to improve options storage
  * Added settings tab to manage dialog size and position
  * Added cutting diagram options defaults storage

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
