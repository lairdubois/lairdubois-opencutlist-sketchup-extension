# -*- coding: utf-8 -*-
# frozen_string_literal: true

#
# from http://d.hatena.ne.jp/alunko/20071021
#
require 'kconv'
require 'fileutils'
require_relative '../../rubyzip/zip'

module Ladb::OpenCutList
module Writexlsx
module ZipFileUtils
  # src  file or directory
  # dest  zip filename
  # options :fs_encoding=[UTF-8,Shift_JIS,EUC-JP]
  def self.zip(src, dest, options = {})
    src = File.expand_path(src)
    dest = File.expand_path(dest)
    FileUtils.rm_f(dest)
    Zip::File.open(dest, create: true) do |zf|
      if File.file?(src)
        zf.add(encode_path(File.basename(src), options[:fs_encoding]), src)
        break
      else
        each_dir_for(src) do |path|
          if File.file?(path)
            zf.add(encode_path(relative(path, src), options[:fs_encoding]), path)
          elsif File.directory?(path)
            zf.mkdir(encode_path(relative(path, src), options[:fs_encoding]))
          end
        end
      end
    end
    FileUtils.chmod(0o644, dest)
  end

  # src  zip filename
  # dest  destination directory
  # options :fs_encoding=[UTF-8,Shift_JIS,EUC-JP]
  def self.unzip(src, dest, options = {})
    FileUtils.makedirs(dest)
    Zip::InputStream.open(src) do |is|
      loop do
        entry = is.get_next_entry
        break unless entry

        dir = File.dirname(entry.name)
        FileUtils.makedirs(dest + '/' + dir)
        path = encode_path(dest + '/' + entry.name, options[:fs_encoding])
        if entry.file?
          File.open(path, File::CREAT | File::WRONLY | File::BINARY) do |w|
            w.puts(is.read)
          end
        else
          FileUtils.makedirs(path)
        end
      end
    end
  end

  def self.each_dir_for(dir_path, &block)
    each_file_for(dir_path, &block)
  end

  def self.each_file_for(path, &block)
    if File.file?(path)
      yield(path)
      return true
    end
    dir = Dir.open(path)
    file_exist = false
    dir.each do |file|
      next if ['.', '..'].include?(file)

      file_exist = true if each_file_for(path + "/" + file, &block)
    end
    yield(path) unless file_exist
    file_exist
  end

  def self.relative(path, base_dir)
    path[base_dir.length + 1..path.length] if path.index(base_dir) == 0
  end

  def self.encode_path(path, encode_s)
    return path unless encode_s

    case encode_s
    when 'UTF-8'
      path.toutf8
    when 'Shift_JIS'
      path.tosjis
    when 'EUC-JP'
      path.toeuc
    else
      path
    end
  end
end
end
end
