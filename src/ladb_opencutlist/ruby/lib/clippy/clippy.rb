require 'fiddle'
require 'fiddle/import'

module Ladb::OpenCutList
  module Clippy
    extend Fiddle::Importer

    FACTOR = 1e10

    case Sketchup.platform
    when :platform_osx
      dlload File.join(__dir__, '../../../bin/osx/lib/libClippy.dylib')
    when :platform_win
      dlload File.join(__dir__, '../../../bin/x86/lib/libClippy.dll')
    end

    extern 'void c_clear_subjects(void)'
    extern 'void c_append_subject(int64_t* coords, size_t len)'

    extern 'void c_clear_clips(void)'
    extern 'void c_append_clip(int64_t* coords, size_t len)'

    extern 'size_t c_union(void)'
    extern 'size_t c_difference(void)'

    extern 'void c_clear_solution(void)'
    extern 'size_t c_get_solution_len(void)'
    extern 'size_t c_get_solution_path_len_at(int index)'
    extern 'int64_t* c_get_solution_path_coords_at(int index)'

    def self.clear
      c_clear_subjects
      c_clear_clips
      c_clear_solution
    end

    def self.clear_subjects
      c_clear_subjects
    end

    def self.append_subject(coords)
      c_append_subject(Fiddle::Pointer[coords.pack('q*')], coords.length)
    end

    def self.append_subjects(paths)
      paths.each do |coords|
        append_subject(coords)
      end
    end

    def self.clear_clips
      c_clear_clips
    end

    def self.append_clip(coords)
      c_append_clip(Fiddle::Pointer[coords.pack('q*')], coords.length)
    end

    def self.append_clips(paths)
      paths.each do |coords|
        append_clip(coords)
      end
    end

    def self.clear_solution
      c_clear_solution
    end

    def self.compute_union
      c_union
      _unpack_solution
    end

    def self.compute_difference
      c_difference
      _unpack_solution
    end

    # -- Utils --

    def self.points_to_coords(points)
      points.map { |point| [ (point.x * FACTOR).to_i, (point.y * FACTOR).to_i ] }.flatten
    end

    def self.coords_to_points(coords)
      points = []
      coords.each_slice(2) { |coord_a, coord_b| points << Geom::Point3d.new(coord_a / FACTOR, coord_b / FACTOR) }
      points
    end

    def self.ccw?(points)
      return true if points.empty?
      area = wedge(points[-1], points[0])
      0.upto(points.size - 2) {|i| area += wedge(points[i], points[i + 1]) }
      area >= 0
    end

    def self.wedge(point1, point2)
      point1.x * point2.y - point2.x * point1.y
    end

    private

    def self._unpack_solution
      solution = []
      (0...c_get_solution_len).each do |index|

        path_len = c_get_solution_path_len_at(index)
        part_coords_ptr = c_get_solution_path_coords_at(index)

        solution << part_coords_ptr[0, path_len * Fiddle::SIZEOF_LONG_LONG * 2].unpack('q*')
      end
      solution
    end

  end
end