defmodule ChatWeb.MainLive.Page.Dialog do
  @moduledoc "Dialog page"
  import ChatWeb.MainLive.Page.Shared
  import Phoenix.LiveView, only: [assign: 3, consume_uploaded_entries: 3, push_event: 3]

  alias Phoenix.PubSub

  alias Chat.Dialogs
  alias Chat.Log
  alias Chat.Memo
  alias Chat.User
  alias Chat.Utils.StorageId

  def init(%{assigns: %{me: me}} = socket, user_id) do
    peer = User.by_id(user_id)
    dialog = Dialogs.find_or_open(me, peer)
    messages = dialog |> Dialogs.read(me)

    PubSub.subscribe(Chat.PubSub, dialog |> dialog_topic())
    Log.open_direct(me, peer)

    socket
    |> assign(:mode, :dialog)
    |> assign(:peer, peer)
    |> assign(:dialog, dialog)
    |> assign(:edit_dialog, false)
    |> assign(:messages, messages)
    |> assign(:message_update_mode, :replace)
  end

  def send_text(%{assigns: %{dialog: dialog, me: me}} = socket, text) do
    if is_memo?(text) do
      dialog |> Dialogs.add_memo(me, text)
    else
      dialog |> Dialogs.add_text(me, text)
    end
    |> broadcast_new_message(dialog, me)

    socket
  end

  def send_file(%{assigns: %{dialog: dialog, me: me}} = socket) do
    consume_uploaded_entries(
      socket,
      :dialog_file,
      fn %{path: path}, entry ->
        data = [
          File.read!(path),
          entry.client_type |> mime_type(),
          entry.client_name,
          entry.client_size |> format_size()
        ]

        {:ok, Dialogs.add_file(dialog, me, data)}
      end
    )
    |> Enum.at(0)
    |> broadcast_new_message(dialog, me)

    socket
  end

  def send_image(%{assigns: %{dialog: dialog, me: me}} = socket) do
    consume_uploaded_entries(
      socket,
      :image,
      fn %{path: path}, entry ->
        data = [File.read!(path), entry.client_type]
        {:ok, Dialogs.add_image(dialog, me, data)}
      end
    )
    |> Enum.at(0)
    |> broadcast_new_message(dialog, me)

    socket
  end

  def show_new(%{assigns: %{me: me, dialog: dialog}} = socket, new_message) do
    socket
    |> assign(:messages, [Dialogs.read_message(dialog, new_message, me)])
    |> assign(:message_update_mode, :append)
  end

  def edit_message(%{assigns: %{me: me, dialog: dialog}} = socket, msg_id) do
    content =
      Dialogs.read_message(dialog, msg_id, me)
      |> then(fn
        %{type: :text, content: text} ->
          text

        %{type: :memo, content: json} ->
          json |> StorageId.from_json() |> Memo.get()
      end)

    socket
    |> assign(:edit_dialog, true)
    |> assign(:edit_content, content)
    |> assign(:edit_message_id, msg_id)
    |> push_event("chat:focus", %{to: "#dialog-edit-input"})
  end

  def update_edited_message(
        %{assigns: %{dialog: dialog, me: me, edit_message_id: msg_id}} = socket,
        text
      ) do
    content = if is_memo?(text), do: {:memo, text}, else: text

    Dialogs.update(dialog, me, msg_id, content)
    broadcast_message_updated(msg_id, dialog, me)

    socket
    |> cancel_edit()
  end

  def update_message(
        %{assigns: %{me: me, dialog: dialog}} = socket,
        {_time, id} = msg_id,
        render_fun
      ) do
    content =
      Dialogs.read_message(dialog, msg_id, me)
      |> then(&%{msg: &1})
      |> render_to_html_string(render_fun)

    socket
    |> push_event("chat:change", %{to: "#dialog-message-#{id} .x-content", content: content})
  end

  def cancel_edit(socket) do
    socket
    |> assign(:edit_dialog, false)
    |> assign(:edit_content, nil)
    |> assign(:edit_message_id, nil)
  end

  def delete_message(%{assigns: %{me: me, dialog: dialog}} = socket, {time, msg_id}) do
    Dialogs.delete(dialog, me, {time, msg_id})
    broadcast_message_deleted(msg_id, dialog, me)

    socket
  end

  def close(%{assigns: %{dialog: dialog}} = socket) do
    PubSub.unsubscribe(Chat.PubSub, dialog |> dialog_topic())

    socket
    |> assign(:dialog, nil)
    |> assign(:messages, nil)
    |> assign(:peer, nil)
  end

  defp dialog_topic(%Dialogs.Dialog{} = dialog) do
    dialog
    |> Dialogs.key()
    |> then(&"dialog:#{&1}")
  end

  defp broadcast_new_message(message, dialog, me) do
    {:new_dialog_message, message}
    |> dialog_broadcast(dialog)

    Log.message_direct(me, Dialogs.peer(dialog, me))
  end

  defp broadcast_message_updated(message_id, dialog, me) do
    {:updated_dialog_message, message_id}
    |> dialog_broadcast(dialog)

    Log.update_message_direct(me, Dialogs.peer(dialog, me))
  end

  defp broadcast_message_deleted(message_id, dialog, me) do
    {:deleted_dialog_message, message_id}
    |> dialog_broadcast(dialog)

    Log.delete_message_direct(me, Dialogs.peer(dialog, me))
  end

  defp dialog_broadcast(message, dialog) do
    PubSub.broadcast!(
      Chat.PubSub,
      dialog |> dialog_topic(),
      message
    )
  end
end
