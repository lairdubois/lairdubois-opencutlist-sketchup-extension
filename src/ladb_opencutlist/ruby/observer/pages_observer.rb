module Ladb::OpenCutList

  class PagesObserver < Sketchup::PagesObserver

    ON_PAGES_CONTENTS_MODIFIED = 'on_pages_contents_modified'.freeze

    def onContentsModified(pages)
      # puts "onContentsModified: #{pages}"

      # Trigger event to JS
      PLUGIN.trigger_event(ON_PAGES_CONTENTS_MODIFIED, { :pages => pages })

    end

  end

end