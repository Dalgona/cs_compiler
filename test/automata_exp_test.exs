defmodule CSCompilerTest do
  use ExUnit.Case
  doctest CSCompiler

  test "greets the world" do
    assert CSCompiler.hello() == :world
  end
end
