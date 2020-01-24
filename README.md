ZeroBot(-Perl)
=========

NOTICE
------

This particular incarnation of ZeroBot, in the midst of yet another swapping of Moo/Moose, is defunct and will no longer be worked on. Instead, I am returning to ZeroBot's origin for his third (or like sixth if you count the *multiple* Perl redesigns) and hopefully final incarnation and once again rewriting him in Python. I recently fell a bit in love with Python despite my fledgling opinions from the past, and given Python's amazing standard library combined with my irritations with managing Perl modules leaves me feeling confident that I can get up to speed again faster than I did with Perl.

In returning to Python, I can do away with the satanic amalgamation of PoCo::IRC within a PoCo::Syndicator and all the joy that working with it brings, have feature modules that actually *fully* unload and are less of a hassle to juggle, and more actively maintained libraries in general. I'm also excited to be able to leverage Async I/O, and well...have a proper OO system built into the language. Moose is dandy, but managing it can be a giant pain.

At any rate, that's all the rambling I'll be doing here. This repository has been renamed and will be archived, and ZeroBot's ongoing development will take place at the original location: [ZeroKnight/ZeroBot](https://github.com/ZeroKnight/ZeroBot). It was a fun foray through Perl, and while I still like the language, its module management truly repels me from working with it for larger projects.

The following is the rest of the README, as it was before archival.

My personal, batshit-insane IRC bot
-------------------------------------

This IRC bot serves no major purpose other than to amuse myself and friends in
the IRC channels that I frequent, thus it doesn't do anything overly special; it
is simply a pet project :)

ZeroBot is designed to be completely modular; he consists only of a simple core
that provides a foundation that **modules** (or **plugins**, if you prefer) are
built on. Thus, ZeroBot can be made to fit **any** role.

Backstory that you probably don't care about
----------------------------------------------

I started writing ZeroBot in Python roughly around December 2011. After some
time, I grew to dislike Python for various reasons and pretty much abandoned my
poor bot, forgetting it even existed for a while. Some time later, yearning for
the deranged antics of my old bot, and keeping a collection of humorous quotes,
I decided to re-write my old bot in a language that wasn't Python.

First I chose C++ as I quite enjoy the language, but not being very proficient
with it, it took more time than I would have liked for a side-project. However,
wanting to learn Perl I decided to jump back in yet again and write up my
beloved old bot in Perl.

Even in this re-write there have been a few periods of where I stopped working
on him for a while, only to come back and re-write his core from scratch. At the
time of this update we're on re-design number 3! This current design is looking
great however, and after catching up to his former capabilities, it's all new
territory from there.

The reason for writing this bot, since the very beginning, was to dive into
learning how to program, and learning what makes the IRC protocol tick. Indeed,
the aforementioned Python iteration was my first real attempt at programming, so
this deranged heap of code means a fair deal to me :)

Huh? You're still here? Okay, uh...
-------------------------------------

If you happen to stumble upon this Bot, be it through advanced boredom or search
engine black magic, do what you will with it. This is, of course, a *personal*
project; no support, limited docs, poor design, nothing making any ounce of
sense at all, etc. You know the deal.

