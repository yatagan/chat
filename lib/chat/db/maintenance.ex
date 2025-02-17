defmodule Chat.Db.Maintenance do
  @moduledoc "DB size and operation mode functions"

  @free_space_buffer_100mb 100 * 1024 * 1024

  def path_writable_size(path) do
    path_free_space(path) - @free_space_buffer_100mb
  end

  def path_free_space(path) do
    System.cmd("df", ["-P", path])
    |> elem(0)
    |> String.split("\n", trim: true)
    |> List.last()
    |> String.split(" ", trim: true)
    |> Enum.at(3)
    |> String.to_integer()
    |> Kernel.*(512)
  rescue
    _ -> 0
  end

  def db_size(db) do
    db
    |> CubDB.current_db_file()
    |> File.stat!()
    |> Map.get(:size)
  end

  def db_free_space(db) do
    db
    |> CubDB.data_dir()
    |> path_free_space()
  end

  def sync_preparation(db) do
    CubDB.set_auto_compact(db, false)
    CubDB.set_auto_file_sync(db, false)
  end

  def sync_finalization(db) do
    CubDB.set_auto_file_sync(db, true)
    CubDB.set_auto_compact(db, true)
  end
end
