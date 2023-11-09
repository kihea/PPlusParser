## Calculator using a Jay Earley parser

You can find a live demo [here](https://kihea.github.io/EarleyCalculator/)

This is an implementation of my [PPlusParser repository](https://github.com/kihea/PPlusParser). Beyond computational linguistics, the project can be used for more abstract computations such as arithmetics.

Rather than going the simple route, this calculator uses an algorithm typically chosen for language parsing. Given a legal arithmetic string, the algorithm uses the predefined grammar to compose an [abstract syntax tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree) in at worst O(n^3) time complexity, and at best O(n), which is then used to perform the necessary calculations.

