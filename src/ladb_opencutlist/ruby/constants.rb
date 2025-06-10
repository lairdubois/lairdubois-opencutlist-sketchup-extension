module Ladb::OpenCutList

    EXTENSION_NAME = 'OpenCutList'.freeze
    EXTENSION_VERSION = '7.0.0-dev'.freeze
    EXTENSION_BUILD = '202506101611'.freeze

    DEFAULT_LANGUAGE = 'en'
    # ENABLED_LANGUAGES = %w[ar cs de en es fr he hu it nl pl pt ru uk zh]
    ENABLED_LANGUAGES = %w[cs de en fr it pl pt ru uk]

    FILE_FORMAT_SKP = 'skp'.freeze
    FILE_FORMAT_STL = 'stl'.freeze
    FILE_FORMAT_OBJ = 'obj'.freeze
    FILE_FORMAT_DXF = 'dxf'.freeze
    FILE_FORMAT_SVG = 'svg'.freeze

end
