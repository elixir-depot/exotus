defmodule Exotus.PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  setup %{test: test} do
    id = test |> :erlang.term_to_binary() |> Base.url_encode64()
    {:ok, id: id}
  end

  describe "OPTIONS" do
    test "fresh file" do
      conn = conn(:options, "/")
      config = Exotus.Plug.Router.init(max_size: 1024)

      conn = Exotus.Plug.Router.call(conn, config)

      assert conn.state == :sent
      assert conn.status == 204
      assert get_resp_header(conn, "tus-version") == ["1.0.0"]

      assert get_resp_header(conn, "tus-extension") == [
               "creation,creation-defer-length,creation-with-upload"
             ]

      assert get_resp_header(conn, "tus-max-size") == ["1024"]
    end
  end

  describe "HEAD" do
    test "fresh file", %{id: id} do
      start_supervised({Exotus.Upload, %{id: id, content_length: 1024}})

      conn =
        :head
        |> conn("/#{id}")
        |> put_req_header("tus-resumable", "1.0.0")

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert conn.state == :sent
      assert conn.status == 200
      assert get_resp_header(conn, "upload-offset") == ["0"]
      assert get_resp_header(conn, "upload-length") == ["1024"]
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end

    test "non existing file", %{id: id} do
      conn =
        :head
        |> conn("/#{id}")
        |> put_req_header("tus-resumable", "1.0.0")

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert conn.state == :sent
      assert conn.status == 404
      assert get_resp_header(conn, "upload-offset") == []
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end

    test "missing tus-resumable header", %{id: id} do
      conn = conn(:head, "/#{id}")

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert conn.state == :sent
      assert conn.status == 412
      assert get_resp_header(conn, "tus-version") == ["1.0.0"]
    end

    test "[extension][creation-defer-length] defered length", %{id: id} do
      start_supervised({Exotus.Upload, %{id: id, content_length: :deferred}})

      conn =
        :head
        |> conn("/#{id}")
        |> put_req_header("tus-resumable", "1.0.0")

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert conn.state == :sent
      assert conn.status == 200
      assert get_resp_header(conn, "upload-offset") == ["0"]
      assert get_resp_header(conn, "upload-defer-length") == ["1"]
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end
  end

  describe "PATCH" do
    test "fresh file", %{id: id} do
      start_supervised({Exotus.Upload, %{id: id, content_length: 1024}})

      conn =
        :patch
        |> conn("/#{id}", "1234567890")
        |> put_req_header("tus-resumable", "1.0.0")
        |> put_req_header("content-type", "application/offset+octet-stream")
        |> put_req_header("upload-offset", "0")

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert conn.state == :sent
      assert conn.status == 204
      assert get_resp_header(conn, "upload-offset") == ["10"]
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
    end

    test "http override", %{id: id} do
      start_supervised({Exotus.Upload, %{id: id, content_length: 1024}})

      conn =
        :post
        |> conn("/#{id}", "1234567890")
        |> put_req_header("tus-resumable", "1.0.0")
        |> put_req_header("content-type", "application/offset+octet-stream")
        |> put_req_header("upload-offset", "0")
        |> put_req_header("x-http-method-override", "patch")

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert conn.state == :sent
      assert conn.status == 204
      assert get_resp_header(conn, "upload-offset") == ["10"]
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
    end

    test "to much", %{id: id} do
      start_supervised({Exotus.Upload, %{id: id, content_length: 8}})

      conn =
        :patch
        |> conn("/#{id}", "1234567890")
        |> put_req_header("tus-resumable", "1.0.0")
        |> put_req_header("content-type", "application/offset+octet-stream")
        |> put_req_header("upload-offset", "0")

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert conn.state == :sent
      assert conn.status == 413
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
    end

    test "more than max", %{id: id} do
      start_supervised({Exotus.Upload, %{id: id, content_length: 1024}})
      config = Exotus.Plug.Router.init(max_size: 5)

      conn =
        :patch
        |> conn("/#{id}", "1234567890")
        |> put_req_header("tus-resumable", "1.0.0")
        |> put_req_header("content-type", "application/offset+octet-stream")
        |> put_req_header("upload-offset", "0")

      conn = Exotus.Plug.Router.call(conn, config)

      assert conn.state == :sent
      assert conn.status == 413
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
    end

    test "Offset mismatch", %{id: id} do
      start_supervised({Exotus.Upload, %{id: id, content_length: 1024}})

      conn =
        :patch
        |> conn("/#{id}", "1234567890")
        |> put_req_header("tus-resumable", "1.0.0")
        |> put_req_header("content-type", "application/offset+octet-stream")
        |> put_req_header("upload-offset", "10")

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert conn.state == :sent
      assert conn.status == 409
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
    end
  end

  describe "[extension][creation] POST" do
    test "fresh file" do
      conn =
        :post
        |> conn("/")
        |> put_req_header("tus-resumable", "1.0.0")
        |> put_req_header("content-length", "0")
        |> put_req_header("upload-length", "1024")
        |> put_req_header(
          "upload-metadata",
          "filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,is_confidential"
        )

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert conn.state == :sent
      assert conn.status == 201
      assert get_resp_header(conn, "location") |> hd() =~ ~r|[A-Za-z0-9]+?|
    end

    test "persists metadata" do
      conn =
        :post
        |> conn("/")
        |> put_req_header("tus-resumable", "1.0.0")
        |> put_req_header("content-length", "0")
        |> put_req_header("upload-length", "1024")
        |> put_req_header(
          "upload-metadata",
          "filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,is_confidential"
        )

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      id = get_resp_header(conn, "location") |> hd()

      conn =
        :head
        |> conn("/#{id}")
        |> put_req_header("tus-resumable", "1.0.0")

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert conn.state == :sent
      assert conn.status == 200
      assert get_resp_header(conn, "upload-offset") == ["0"]
      assert get_resp_header(conn, "upload-length") == ["1024"]

      assert get_resp_header(conn, "upload-metadata") == [
               "filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,is_confidential"
             ]
    end

    test "with upload" do
      conn =
        :post
        |> conn("/", "1234567890")
        |> put_req_header("tus-resumable", "1.0.0")
        |> put_req_header("content-length", "10")
        |> put_req_header("upload-length", "1024")
        |> put_req_header("content-type", "application/offset+octet-stream")
        |> put_req_header(
          "upload-metadata",
          "filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,is_confidential"
        )

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert get_resp_header(conn, "upload-offset") == ["10"]

      id = get_resp_header(conn, "location") |> hd()

      conn =
        :head
        |> conn("/#{id}")
        |> put_req_header("tus-resumable", "1.0.0")

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert conn.state == :sent
      assert conn.status == 200
      assert get_resp_header(conn, "upload-offset") == ["10"]
    end

    test "with upload - file to big" do
      conn =
        :post
        |> conn("/", "1234567890")
        |> put_req_header("tus-resumable", "1.0.0")
        |> put_req_header("content-length", "10")
        |> put_req_header("upload-length", "9")
        |> put_req_header("content-type", "application/offset+octet-stream")
        |> put_req_header(
          "upload-metadata",
          "filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,is_confidential"
        )

      conn = Exotus.Plug.Router.call(conn, Exotus.Plug.Router.init([]))

      assert conn.state == :sent
      assert conn.status == 413
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
    end
  end
end
