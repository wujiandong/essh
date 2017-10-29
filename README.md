# Essh

## Installation
  1. Add `essh` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:essh, "~> 0.0.1"}]
    end
    ```

  2. Ensure `essh` is started before your application:

    ```elixir
    def application do
      [applications: [:essh]]
    end
    ```
## Usage

1. cat ip.txt |> mix essh --stdin -c "hostname" 
2. mix essh -f ip.txt -c "hostname"
3. mix essh -f ip.txt -u "/tmp/src /tmp/dest"


-f file
-c command
-u uploadfile   first arg is src, second arg is  dest






