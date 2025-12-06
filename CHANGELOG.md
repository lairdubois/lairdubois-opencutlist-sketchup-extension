CHANGELOG
=========

This changelog references the relevant changes (bug and security fixes) done
in 8.x, 7.x, 6.x, 5.x, 4.x, 3.x, 2.x, 1.x and 0.x versions.

# 8.0.0 (WIP)

  * Added Smart Reshape Tool
  * Added + / - shortcuts in Smart Handle Tools

## Lab

### 2025-12-06
  * Various improvements
### 2025-11-30
  * Added @batch variable in Packing designation formulas
  * Updated CS, ES, NL, SR languages
### 2025-11-27
  * Fixed Smart Handle Tool with flat entities
### 2025-11-26
  * Improved Smart Tools
  * Fixed Sketchup 2020 packing preview display bug
### 2025-11-24
  * Improved Smart Reshape Tool
  * Fixed VCB arithmetic parser
### 2025-11-20
  * Added selection by context menu tree in Stretch Tool
  * Added capability to Smart Handle Tool to hangle any group or component
  * Fixed Stretch Tool when view projection is parallel to model axes

# 7.1.0 (WIP)

  * Added NL language
  * Added "normal" font size value to settings
  * Added Outliner "Deep Rename parts" feature
  * Added Outliner "Deep Make Unique" feature
  * Added Outliner "Create Group" feature
  * Added Outliner "Create Component" feature
  * Added Outliner "Drag and Drop" feature
  * Added @batch variable in Packing designation formulas
  * Improved PathFormulaWrapper. It now contains instance objects
  * Improved export with grouped parts activated
  * Improved Smart Handle Tool: 
    * Ability to edit copies during preview
    * Ability to handle any single or multiple group
    * Ability to select siblings of a part for "Select", "Copy in line" and "Distribute" actions
  * Improved Smart Tools length capture by adding the possibility to use arithmetic operations (+-*/)
  * Fixed rounding errors for metric dimensions in cutting diagrams
  * Fixed DXF line type error
  * Removed part oversizes attributes

## Lab

### 2025-11-30
  * Added @batch variable in Packing designation formulas
  * Updated CS, ES, NL, SR languages
### 2025-11-27
  * Fixed Smart Handle Tool with flat entities
### 2025-11-26
  * Fixed VCB float converter
  * Updated EN, ES, PT, RU languages
### 2025-11-24
  * Fixed VCB arithmetic parser
### 2025-11-20
  * Added selection by context menu tree in Stretch Tool
  * Added ability to Smart Handle Tool to hangle any group or component
### 2025-11-17
  * Updated HU language
### 2025-11-12
  * Updated HU language
### 2025-11-06
  * Fixed PackingSolver [issue #267](https://github.com/fontanf/packingsolver/issues/267)
### 2025-10-21
  * Added absolute and relative point read from VCB - [discussion](https://forums.sketchup.com/t/explore-the-opencutlist-lab/341006/13)
### 2025-10-19
  * Improved Smart Tools length capture by adding the possibility to use arithmetic operations - [discussion](https://forums.sketchup.com/t/explore-the-opencutlist-lab/341006/6)
### 2025-10-17
  * Added -@ VCB shortcut
  * Updated codemirror style
  * Fixed Outliner "Deep Make Unique" feature with nested components
  * Fixed Outliner "Deep Rename Parts" feature with nested components
### 2025-10-14
  * Improved Smart Handle Tool by adding the possibility to change copies during preview
  * Fixed Saved parts list numbers for Windows

# 7.0.1 (2025-09-30)

  * Fixed old MacOS compatibility (min 10.13)

# 7.0.0 (2025-09-17)

  * New Cutting Diagram engine (with nesting capabilities)
  * Added Outliner tab
  * Added Smart Draw tool
  * Added Smart Handle tool
  * Added Cut price to material attributes
  * Added Definition and Instance wrappers in formulas (allows to read DC and custom attributes)
  * Added Material wrapper in formulas
  * Added Move Axes action on Smart Axes Tool
  * Added Export Paths action on Smart Export Tool
  * Added Switch YZ axes option to Smart Export Tool on Export 3D part action
  * Added Material type separators in materials tabs when sorted by type
  * Added Export 2D projections left, right, front, back
  * Added QRCodes in the label editor
  * Added Duplicate element in labels editor
  * Added Duplicate column in the export editor
  * Added the Labels button to the Parts List
  * Added _use_count_ parameter to 2D and 3D drawing writers
  * Added handle to manually reorder material prices list
  * Added an option to customize group sorting
  * Added Export parts list to XLSX
  * Added Export drawing with overflows
  * Changed solid wood coefficient from estimate params to material attributes
  * Improved export drawing to Layout: adding the ability to add in a new page of an existing file
  * Improved labels formulas
  * Improved smart tools picker
  * Improved Smart Paint Tool by adding scrolling in the materials list
  * Improved surface detection
  * Improved Material import from SKM (allows new or replace)
  * Improved Material forms (allows using texture on new material)
  * Improved Layout feature to be able to align on active view axes
  * Improved Material price attributes to add the ability to set price for thickness or section
  * Replaced Highlight Part Tool with Smart Axes Tool
  * Fixed face untyped material removing when editing sheet good part properties
  * Fixed truncated text in OpenCutList tools on Windows if system fonts are scaled

## Lab

### 2025-09-10
  * Improved UI
  * Updated CR
### 2025-09-09
  * Improved material forms (allows using texture on new material)
  * Fixed DLL loading crash when using multiple SketchUp instances on Windows
  * Updated CR, ZH languages
### 2025-09-08
  * Various UI improvements
  * Updated CR languages
### 2025-09-07
  * Added rectangular cuts export for Rectangle and Irregular cutting diagram types 
  * Updated EN, ZH, CR languages
### 2025-09-06
  * Added font size option in the settings tab 
  * Fixed various packing solver bugs
  * Updated languages
### 2025-09-03
  * Fixed Smart Handle Tool when model axes are changed
  * Added the ability to draw a single part
  * Updated ZH languages
  * Updated PackingSolver dependency
### 2025-08-27
  * Finalized translations
  * Added width oversize attribute for edge banding material type
### 2025-08-24
  * Updated RU and ZH languages
### 2025-08-23
  * Added toggle group visibility button on each row of parts list summary
### 2025-08-22
  * Improved Smart Paint Tool by adding scrolling in materials list
### 2025-08-19
  * Updated AR and RU languages
  * Minor improvements in Smart Export Tool
### 2025-08-18
  * **Changed** DXF / SVG layer naming (replace _DEPTH_0000_000_ by _0000_000Z_)
  * Added cutlist row context menu
### 2025-08-15
  * Fixed DXF black color
### 2025-08-14
  * Added support for SketchUp tags (name + color) for DXF/SVG export of paths
### 2025-08-12
  * Updated HU language
### 2025-08-11
  * Added HU language
  * Updated IT, PT, RU
### 2025-08-08
  * Fixed SmartDrawTool
  * Fixed Packing irregular modal
### 2025-08-07
  * Added snap centroid on SmartDrawTool
  * Improved Outliner
### 2025-08-05
  * Open newly created material properties after duplication 
  * Updated ZH language
### 2025-08-02
  * Added progress timer 
  * Added VI language
### 2025-08-01
  * Fixed packing + labels back face edge preview
  * Added cutting diagram regenerate button to bypass cache
  * Updated translations
### 2025-07-27
  * Added ES language
### 2025-07-07
  * Updaded AR language

---

# 6.4.0 (2025-05-27)

  * Added **Polish** language
  * Added **Hungarian** language

# 6.3.2 (2025-04-23)

  * Fixed copy to clipboard for SketchUp 2025

# 6.3.1 (2025-02-26)

  * Fixed for SketchUp 2025

# 6.3.0 (2024-10-22)

  * Added **Vietnamese** language
  * Improved part shape 2D projection when using cuts opening components
  * Fixed SVG/DXF cutting diagram export when part numbers are numeric
  * Fixed cutting diagram bug
  * Fixed SketchUp defaults read when an exception occurs

# 6.2.0 (2024-03-22)

  * Added **Chinese** language
  * Fixed multiline material description UI bug

# 6.1.0 (2024-03-05)

  * Added **Portuguese** language (thanks to Henny Ferreira for joining the translators team)
  * Fixed _Clippy_ loading when OpenCutList installed under a non-ASCII path
  * Fixed table row size reload on startup
  * Fixed veneer default material attributes
  * Improved Smart Tools tooltip behavior
  * Improved Smart Axes Tools flip action planes color

# 6.0.1 (2024-02-26)

  * Fixed removed languages selection

# 6.0.0 (2024-02-21)

  * Added **Smart Export** Tool and Module to export parts to 3D (STL, OBJ) or 2D (SVG, DXF) files
  * Added _Hide material colors_ cutlist option
  * Added edge material color display in part list, cutting diagram and labels
  * Added edit material for edge and veneer virtual parts
  * Added labels formulas
  * Added labels part preview element
  * Added labels remove all elements button
  * Added export remove all columns button
  * Added table row size options
  * Added Toggle button in cutlist tags filters to switch from "present" to "not present"
  * Added Mass and Currency custom precision in settings tab
  * Added item to reset dialog position to default in extensions menu
  * Added Description and URL fields to Material's attributes
  * Added URL field to Part's attributes
  * Added €/m price unit to sheet good and veneer materials
  * Added ∑ rough length, area and volume to all material types except hardware in cutlist summary
  * Added list of leftover to keep at the end of 2D cutting diagrams + button to copy them to clipboard
  * Added a button to select all unplaced parts in parts list from cutting diagrams
  * Added ability to configure material weight per raw instance
  * Added ability to estimate parts weight and cost by cut volume only
  * Improved smart tool last used action now stored globally to keep it on new SketchUp session
  * Improved dimension default style in Layout document after exporting _Drawing_ to Layout
  * Changed material color bullet from drop to circle but present in all lists
  * Dropped **Polish** language for lack of contributors
  * Dropped **Portuguese** language for lack of contributors
  * Dropped **Simplified Chinese** language for lack of contributors
  * Dropped **Vietnamese** language for lack of contributors

---

# 5.1.2 (2023-11-29)

  * Added teaser cutting diagram "Export" button

# 5.1.1 (2023-10-30)

  * Avoid negative dimensions input

# 5.1.0 (2023-10-18)

  * Added **Dutch** language (thanks to Dany Dhondt, Eric Lugtigheid and Koen Dejonckheere)
  * Added **Simplified Chinese** language (thanks to liutao91)

# 5.0.4 (2023-09-14)

  * Fixed "Export to Layout" hang

# 5.0.3 (2023-09-13)

  * Fixed the dimension parser that misinterpret decimal separator
  * Fixed wrong counting of invalid sized parts in 2D
  * Fixed Bottom right notification box no long print
  * Reversed picker cursor
  * Improved part material detection
  * Improved tokenfield dimension regex
  * Improved Smart Axes Tool "edit part" properties by selecting part entity
  * Added active named path to printable headers
  * Added compare functions to NumericWarapper

# 5.0.2 (2023-06-20)

  * Fixed Architecture dimension parser
  * Fixed Reset standard bar or sheet configured on cutting diagram 1D or 2D if it no longer exists on material
  * Fixed Escape special characters in material names
  * Improved Export Cutlist "Copy" feature now puts a TSV string to clipboard
  * Improved Ukrainian terms
  * Improved Russian terms

# 5.0.1 (2023-05-22)

  * Added `to_fbm` function to VolumeWrapper
  * Improved Smart Tool element picker
  * Improved cutting diagram dimensions display
  * Fixed hide all Draw buttons if WebGL is not supported
  * Fixed import freeze when the model is empty
  * Fixed Export to Layout freeze (SketchUp < 2022) by replacing ComponentDefinition::save_copy use by ComponentDefinition::save_as

# 5.0.0 (2023-05-11)

  * Added **Ukrainian** language (thanks to Kostyantyn and Andriy)
  * Added new **Drawing** module with exploded view and export to *Layout* (SketchUp 2018+ only)
  * Added new **Veneer Material Type**
  * Added new **Smart Paint** tool (rewrite of previous version) + new icon
  * Added new **Smart Axes** tool + new icon
  * Added module to *export* and *import* **presets** to and from json file
  * Added new property to sort labels according to cutting diagram bins
  * Added used and unused proportion display in Estimate summary and details
  * Added feature to duplicate material including all attributes
  * Added left and right arrow shortcut keys to change current material in Smart Paint tool
  * Added hide edge preview option in 2D cutting diagram (default = true)
  * Added layers (SketchUp tags) column to part and instance list exports
  * Added focus SketchUp window after selecting tool (SketchUp 2021.1+)
  * Removed **Dutch** language due to lack of support
  * Renamed Reports to Estimate
  * Renamed Tags to Badges
  * Improved materials property dialog : It is now possible to add, change and clear texture on a material
  * Improved color pickers : It's now possible to select custom color in picker (SketchUp 2021+)
  * Saved last material export / import and part export used folder
  * Fixed cutting diagram bins number to be displayed even if _Group Similar Panels_ option is ON
  * Fixed cutting diagram 2D edge drawing to correspond to counter-clockwise rotation of part's name
  * Fixed missed exported edges std dimensions on folded parts
  * Fixed missed oversize asterisk indicator in cutting diagram parts lists
  * Improved part's material detection by ignoring edges banding and veneer material types applied on faces
  * Improved summary cells: unavailable cells in parts list summary are hatched instead of displaying "-" character
  * Improved UX : Added "escape" key to 1. close modals, 2. minimize OpenCutList dialog
  * Improved UX : Added Double click behavior on material button of the Smart Paint Tool to edit the corresponding material

---

# 4.1.3 (2023-02-28)

  * Added teaser "Drawing" button

# 4.1.3 (2023-02-28)

  * Added teaser "Drawing" button.

# 4.1.2 (2023-01-27)

  * Fixed forum loading error due to Open Collective API changes

# 4.1.1 (2023-01-05)

  * Fixed highlight part tool error when part's material doesn't have type

# 4.1.0 (2023-01-03)

  * Added **Vietnamese** language (thanks to Nguyen Ngoc Tan for joining the translators team)
  * Tweaks in 2D cutting diagram algorithm
  * Added sort tab in Labels options
  * Added material type variable to part list and instance list export
  * Fixed wrong exported cutting length and width when edge reduction - on instances list
  * Fixed smart paint tool selection from materials tab (Windows)
  * Fixed highlight part paint tool to ignore edges parts
  * Fixed smart paint tool crash when switching model
  * Improved leftovers dimensions display in 1D cutting diagrams

# 4.0.1 (2022-10-06)

  * Fixed wrong exported cutting length and width when edge reduction

# 4.0.0 (2022-09-21)

  * Added **SmartPaint tool**
  * Added cutlist **export customization**
  * Added copy to clipboard from Export preview
  * Added cutting diagram 1D progress bar
  * Added cutting diagram 2D progress bar
  * Added generate cutlist menu item (ready to configure a custom keyboard shortcut)
  * Added progress feedback on generate cutlist and list materials
  * Added page description to printed part list
  * Added re-load material texture
  * Added reset all model prices (materials and parts) feature
  * Added news reactions icons
  * Improved disabled edge cell display in part list
  * Now only standard sheet and bar use dim prices in reports
  * Merged instance names in grouped parts
  * Improved ruby i18n string getter to support `$()`
  * Fixed edge std size display
  * Fixed report crash when sheet good or dimensional material don't have a standard size
  * Removed deprecated use of `URI.escape`

---

# 3.0.2 (2022-02-27)

  * Fixed TextArea auto height scroll bug
  * Fixed a few translation errors
  * Added label size 8

# 3.0.1 (2021-12-11)

  * Added translator language "zz" (English with Transifex line numbers) - Only available in DEV environment
  * Now automatically store OpenCutList dialog size and position on resize and move when using SketchUp >= 2021.1
  * Save default _mass_unit_ and _currency_symbol_ to model even if it is not modified from default values
  * Improved document filename when printing to PDF
  * Improved selection warning feedbacks in cutlist, cutting diagrams, labels and reports
  * Improved 'enter' key catch for validation in modal's textinputs
  * Fixed cutting diagram part list sort when using letter for part's number
  * Fixed area and volume summary

# 3.0.0 (2021-11-14)

  * Added **Docs** button to access online documentation : https://docs.opencutlist.org
  * Added capability to consider a part as multiple layers along its thickness
  * Added Description display on parts
  * Added Number or Name part's identifier option on cutting diagrams
  * Added a global cutlist option to disable mirrored part detection
  * Added primary cuts summary below cutting diagrams if *always visible* option is activated
  * Added retina screen support for highlight part tool
  * Added *top* anchors position for label's elements
  * Added *Description* field to labels elements list
  * Added a new tab in cutlist part property modal to groups material dependent properties
  * Added buttons to store and remove custom colors values from color inputs
  * Improved 2D cutting diagram selection strategy
  * Improved arrow display in labels part thumbnail
  * Improved tags render on labels from single line to one tag by line
  * Fixed display units from Preferences when using fractional inches
  * Fixed bug when preset's name contains numbers only
  * Fixed text input reset value
  * Fixed stored part number increment if letter and greater than 'Z'

---

# 2.1.1 (2021-08-02)

  * Added thickness fields to labels
  * Added total cut length in cutting diagram summary
  * Added model description in printable headers if it is defined
  * Fixed forum conversation tag filter
  * Fixed bug in preset when names contains quote
  * Improved dimensions display for small parts in cutting diagrams
  * Leading/trailing spaces of material names removed during import

# 2.1.0 (2021-05-28)

  * Added labels start offset
  * Added entity named path field in Labels
  * Added print margin option in settings tab
  * Cleaner drawing of the arrow in the highlight tool for front and back view
  * Better handling of summable length/width in the parts list. _Rough dimensions are shown when part is summable, even if the part has no oversize to make the sorting order more obvious._

# 2.0.1 (2021-04-13)

  * Global and Model preset are now sorted
  * Added Ignore grain direction part attribute
  * Added edges fields to Labels
  * Added tags in cutting diagram part list
  * Added edges in cutting diagram 2D part list
  * Improved cutting diagram 2d dimensions display
  * Fixed export skp and skm path on win platform
  * Fixed offcut bug (Issue #285)

# 2.0.0 (2021-03-23)

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

---

# 1.9.10 (2020-12-17)

  * Changed OCL length dimension precision from 0.000000 to 0.000 and adapt it if model length precision is higher
  * Added **Spanish** language (thanks to Leonardo Romero Giménez for joining the translators team)
  * Fixed a bug in 1D packing pertaining to offcuts
  * Fixed a bug highlight part tool when part drawing was in sub group

# 1.9.9 (2020-11-19)

  * Added "News" tab
  * Added "Forum" tab
  * Fixed "Highlight part" tool
  * Improved material attributes default according to unit system
  * Improved thickness and section precision display
  * Improved readability of square feet area dimensions
  * Changed ft³ to FBM (foot, board measure) for Material Solid Wood

# 1.9.8 (2020-10-28)

  * Improved "self-updater" workflow

# 1.9.7 (2020-10-21)

  * Added embedded tutorial's videos
  * Improved "undo" management for a better User Experience :P
  * Minor Fixes and Improvements

# 1.9.6 (2020-10-17)

  * Fixed Ruby 2.7.0 deprecated calls
  * Fixed Layer0 visibility detection
  * Fixed Dimension regex for *X' X X/X'* input format
  * Improved ComponentDefinition and Material uuids management

# 1.9.5 (2020-10-01)

  * Fixed cumulative length or width on folded parts
  * Added **Portuguese** language (thanks to Nayton Sanches Barbosa for joining the translators team)
  * Added sponsor objective display
  * Added cutting diagram (1d and 2d) capability to compute only for selected (in part list) parts
  * Added possibility to add a quantity in cutting diagram 1d and 2d "offcut" field
  * Added public message of backers in sponsor list
  * Added link to tutorials list on GitHub in "More" tab
  * Improved dimension token field input

# 1.9.4 (2020-09-11)

  * Fixed cutting diagrams 2D rotated part dimensions display bug
  * Fixed cutting diagrams crash when using non letter part numbers

# 1.9.3 (2020-08-27)

  * Fixed cutting diagrams 1D bug introduced in 1.9.2

# 1.9.2 (2020-08-27)

  * Fixed cutting size with edge reduction in cutting diagrams
  * Added **Italian** language (thanks to Pierluigi Colombo for joining the translators team)
  * Added part oversize view
  * Added edit part tab memory
  * Added cutting diagram 1d / 2d options tab memory
  * Added textinput reset button
  * Improved russian translation

# 1.9.1 (2020-07-05)

  * Fixed impossible final area
  * Fixed material unique name
  * Fixed IE limitations on url parameter size
  * Improved cutlist part number storage
  * Rollback twig to 1.13.3 for IE compatibility

# 1.9.0 (2020-06-04)

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

# 1.8.4 (2020-01-09)

  * Added part "Number" column in cutlist instance export
  * Removed $debug global variable in rchardet lib

# 1.8.3 (2019-12-19)

  * Added Materials order option
  * Cutlist highlight multiple parts improvements
  * Sponsor ad

# 1.8.2 (2019-12-12)

  * Fixed Material name and color form

# 1.8.1 (2019-11-20)

  * Added edge 'copy to all' shortcut
  * Added multiple edition of parts in cutlist
  * Added sponsor tab
  * Added cutting diagram part list display option

# 1.8.0 (2019-10-01)

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

# 1.7.1 (2019-06-30)

  * Added missing translations
  * Added material tint capabilities
  * Added part axes management
  * Added 'add unavailable' std dimension to material on cutlist group
  * Added group's material average color in cutlist

# 1.7.0 (2019-06-10)

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

# 1.6.3 (2019-05-09)

  * Export cutlist labels
  * New language management improvement
  * Fixed cutlist crash on Sketchup 2014

# 1.6.2 (2019-04-23)

  * Added custom language option in settings
  * Added raw volume in all type of material in cutlist summary
  * Added cutlist "width" separators if first sort order is width on solid wood material parts
  * Fixed Highlight tool bug with simple ComponentInstance children

# 1.6.1 (2019-02-15)

  * Reverted i18next javascript lib for compatibility issues
  * Javascripts string polyfills
  * Fixed some IE 9 issues

# 1.6.0 (2019-02-11)

  * Added Cutlist part's labels
  * Added "*Highlight parts in model*" option on entire cutlist and groups

# 1.5.3 (2018-12-10)

  * Cutlist export now includes part numbers

# 1.5.2 (2018-11-01)

  * Reset imported material UUID

# 1.5.1 (2018-07-18)

  * Fixed settings storage
  * Changed startup file structure
  * Hide cutlist group's raw dimensions if no length or width increase is defined
  * Added persistent material UUID mechanism to improve options storage
  * Added settings tab to manage dialog size and position
  * Added cutting diagram options defaults storage

# 1.5.0 (2018-06-25)

  * Added bin packing interface for material of type *Sheet good*
  * Added 2D bin packing library
  * Fixed conversion to local units. Input fields recognize other length units than model units.

# 1.4.2 (2018-06-06)

  * Improved layer visibility management in component faces detection

# 1.4.1 (2018-04-09)

  * Fixed cutlist volume summary
  * Added instance identical names count

# 1.4.0 (2018-04-01)

  * Added new material type : *Dimensional*
  * Added "*Highlight part in model*" button in part's row and edit modal
  * Added "*Edit 'XXX' material*" button in cutlist's group context menu
  * Added unit options observer
  * Added display of length unit in cutlist header
  * cutlist options are stored into model attributes (and SU defaults). It permits to keep cutlist option inside the SKP file.

# 1.3.0 (2018-03-16)

  * Added dynamic components support !
  * Added instance names (if present) in cutlist part rows
  * Fixed part size calculation when a component contains multiples child groups
  * Excluded _always_face_camera_ components from cutlist
  * Treat _cuts_opening_ components has groups
  * Add CHANGELOG link in about tab

# 1.2.3 (2018-03-12)

  * Added dimension column order strategy option in cutlist tab

# 1.2.2 (2017-12-15)

  * Fixed material name update bug on SU 2018

# 1.2.1 (2017-09-30)

  * Added 'Import', 'Export' material to .skm files capabilities
  * Added 'Remove' button on material panel

# 1.2.0 (2017-06-09)

  * Added 'Save part numbers' feature
  * Added 'generated at' on cutlist print
  * Added model, selection and materials observers
  * Added option to save material cutlist defaults manually
  * Added export options
  * Sanitized length values in cutlist export by removing the ~

# 1.1.1 (2017-04-17)

  * Fixed cutlist export bug when export path contains spaces
  * Fixed cutlist export dimensions improvements
  * Removed "x" before quantity in cutlist
  * Sketchup 2014 compatible

# 1.1.0 (2017-04-14)

  * Added cutlist export to CSV
  * Added cumulable feature on parts
  * Added orientation locked on axis on parts

# 1.0.1 (2017-04-11)

  * I18n loading bugfix

# 1.0.0 (2017-04-11)

  * Added ruby access to i18n files
  * Added SU menus to open tabs
  * Switched to 1.0 release

---

# 0.4.6 (2017-04-09)

  * Saving Dialog's size (SU 17 only)
  * Added sticky tab header

# 0.4.5 (2017-01-14)

  * Cutlist part_order_strategy option
  * Cutlist hide_raw_dimensions option
  * Cutlist hide_final_dimensions option
  * Cutlist hide_untyped_material_dimensions option
  * Cutlist hidden_group_ids
  * Cutlist edit groups
  * Materials improve std_thickness input field
  * i18n statically loaded into html to avoid dynamic loading file on runtime (not allowed on all platforms)

# 0.4.4 (2017-01-05)

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

# 0.4.3 (2016-12-28)

  * cutlist inherited and child materials
  * I18n support
  * UI improvements

# 0.4.2 (2016-12-18)

  * Cutlist considers all components that contains faces. Not only leaf components.
  * Cutlist area and volume summary bugfix

# 0.4.1 (2016-12-16)

  * cutlist options bugfix
  * compute_faces_bounds now considers groups
  * Add no hard wood material warning in cutlist
  * Edit part name and material from cut list
  * View part thumbnails
  * UI improvements
  * JS <> Ruby exchange protocol rewritten

# 0.4.0 (2016-12-14)

  * New 'Materials' module
  * Ability to manage option on each material
  * cutlist UI improvements

# 0.3.4

  * cutlist ignore flat components
  * Ruby > JS call encode parameter to accept any chars

# 0.3.3 (2016-12-08)

  * Standard thickness option
  * Standard thickness check
  * Cut list options modal improvements

# 0.3.2 (2016-12-07)

  * Add "piece number sequence by group" in cut list options
  * Add "piece number with letter" in cut list options
  * Add cutlist summary
  * cutlist generate errors and warnings
  * cutlist options improvements
  * UI improvements
  * Save options to localStore

# 0.3.1 (2016-12-06)

  * Bug fix : cutlist generate fail on Windows after model save
  * Bug fix : Hide / Show cutlist group fail on SU prior 2017
  * Uses JS localStorage to save user settings
  * cutlist : continuous pieces code increment

# 0.3.0 (2016-12-05)

  * Bug fix : Sketchup 2016 dialog display on PC
  * OS detection
