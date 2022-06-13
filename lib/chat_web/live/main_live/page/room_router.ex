defmodule ChatWeb.MainLive.Page.RoomRouter do
  @moduledoc "Route room events"

  import Phoenix.LiveView, only: [push_event: 3]

  alias ChatWeb.MainLive.Index
  alias ChatWeb.MainLive.Page

  #
  # LiveView events
  #

  def event(socket, event) do
    case event do
      {"create", %{"new_room" => %{"name" => name, "type" => type}}} ->
        socket |> Page.Lobby.new_room(name, type |> String.to_existing_atom())

      {"approve-request", %{"hash" => hash}} ->
        socket |> Page.Room.approve_request(hash)

      {"cancel-edit", _} ->
        socket |> Page.Room.cancel_edit()

      {"edited-message", %{"room_edit" => %{"text" => text}}} ->
        socket |> Page.Room.update_edited_message(text)

      {"edit-message", %{"id" => id, "timestamp" => time}} ->
        socket |> Page.Room.edit_message({time |> String.to_integer(), id})

      {"download-message", %{"id" => id, "timestamp" => time}} ->
        socket |> Page.Room.download_message({time |> String.to_integer(), id})

      {"delete-message", %{"id" => id, "timestamp" => time, "type" => "room"}} ->
        socket |> Page.Room.delete_message({time |> String.to_integer(), id})

      {"delete-messages", params} ->
        socket |> Page.Room.delete_messages(params)

      {"toggle-messages-select", params} ->
        socket |> Page.Room.toggle_messages_select(params)

      {"import-images", _} ->
        socket |> push_event("chat:scroll-down", %{})

      {"import-files", _} ->
        socket |> push_event("chat:scroll-down", %{})

      {"close", _} ->
        socket |> Page.Room.close()
    end
  end

  #
  # Internal events
  #

  def info(socket, message) do
    case message do
      {:new_message, glimpse} ->
        socket |> Page.Room.show_new(glimpse)

      {:updated_message, msg_id} ->
        socket |> Page.Room.update_message(msg_id, &Index.message_text/1)

      {:deleted_message, msg_id} ->
        socket |> Page.Room.hide_deleted_message(msg_id)
    end
  end
end
