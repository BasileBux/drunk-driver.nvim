# drunk-driver.nvim

I don't like the existing LLM plugins for Neovim, so I am doing my own.

> [!WARNING]
> This plugin is in construction and not ready for use.

## Rant

The openai thinking sucks because they give you almost nothing so I didn't (and
won't ever) implement it. The openai docs for function calling are a joke. Understanding
what is happening and what you need to put in your code is a nightmare. I had to
guess and try a bunch of stuff until something worked. When reading the docs you
can obviously see that it was written by chatGPT and wasn't proofread by a human.
Because who the fuck still reads docs manually in the big 25 anyways right?

Nobody gets any profit over the fact that all llm APIs are different and have stupid
different formats for everything. Thinking is implemented differently for each provider
which sucks. Tool calling is imlpemented differently for each provider which sucks.
