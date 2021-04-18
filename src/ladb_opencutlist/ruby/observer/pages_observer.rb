module Ladb::OpenCutList

  require 'singleton'

  class PagesObserver < Sketchup::ModelObserver

    include Singleton

    ON_PAGES_CONTENTS_MODIFIED = 'on_pages_contents_modified'.freeze

    def onContentsModified(pages)
      # puts "onContentsModified: #{pages}"

      # Trigger event to JS
      Plugin.instance.trigger_event(ON_PAGES_CONTENTS_MODIFIED, { :pages => pages })

    end

  end

end