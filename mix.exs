defmodule CSCompiler.MixProject do
  use Mix.Project

  def project do
    [
      app: :cs_compiler,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: "https://github.com/Dalgona/cs_compiler"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.18"}
    ]
  end
end
