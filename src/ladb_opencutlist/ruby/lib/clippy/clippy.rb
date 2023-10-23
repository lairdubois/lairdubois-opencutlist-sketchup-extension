require 'fiddle'
require 'fiddle/import'

module Ladb::OpenCutList
  module Clippy
    extend Fiddle::Importer

    FACTOR = 1e13

    case Sketchup.platform
    when :platform_osx

      dlload File.join(__dir__, '../../../bin/osx/lib/libClippy.dylib')

      extern 'void c_clear_subjects(void)'
      extern 'void c_append_subject(int64_t* coords, size_t len)'

      extern 'void c_clear_clips(void)'
      extern 'void c_append_clip(int64_t* coords, size_t len)'

      extern 'size_t c_compute_union(void)'
      extern 'size_t c_compute_difference(void)'

      extern 'void c_clear_solution(void)'
      extern 'size_t c_get_solution_len(void)'
      extern 'size_t c_get_solution_path_len_at(int index)'
      extern 'int64_t* c_get_solution_path_coords_at(int index)'

    when :platform_win
      # TODO : Compile a valid DLL of CLippy ...
    end

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
      c_compute_union
      _unpack_solution
    end

    def self.compute_difference
      c_compute_difference
      _unpack_solution
    end

    # -- Utils --

    # Convert Array<Geom::Point3d> to Array<Integer>
    def self.points_to_coords(points)
      points.map { |point| [ (point.x * FACTOR).to_i, (point.y * FACTOR).to_i ] }.flatten
    end

    # Convert Array<Integer> to Array<Geom::Point3d>
    def self.coords_to_points(coords, z = 0.0)
      points = []
      coords.each_slice(2) { |coord_a, coord_b| points << Geom::Point3d.new(coord_a / FACTOR, coord_b / FACTOR, z) }
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

        # Retrieve the solution length (= number of coords)
        path_len = c_get_solution_path_len_at(index)

        # Retrieve solution array pointer
        path_coords_ptr = c_get_solution_path_coords_at(index)
        path_coords_ptr.size = path_len * Fiddle::SIZEOF_LONG_LONG * 2  # Fiddle::SIZEOF_LONG_LONG * 2 = sizeof(int64_t)

        # Unpack pointer data to Ruby Array<Integer> (q* to read 64bits integers)
        solution << path_coords_ptr.to_str(path_coords_ptr.size).unpack('q*')

        # Free pointer
        Fiddle.free(path_coords_ptr)

      end
      solution
    end

  end
end