(declare-project
  :name "toolbox"
  :description "a collection of useful janet functions, libraries and more"
  :dependencies ["https://github.com/janet-lang/spork.git"]
  :author "tionis.dev"
  :license "MIT"
  :url "https://tasadar.net/tionis/tools"
  :repo "git+https://tasadar.net/tionis/tools")

(declare-source
  :source ["toolbox"])

(declare-native
  :name "toolbox/set"
  :source ["src/set.c"])
