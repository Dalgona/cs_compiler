# CSCompiler

컴파일러 시간에 배운 것들을 Elixir 프로그래밍 언어로 구현해 봄.

## 내용

* `lib/cs_compiler/dfa.ex`

    * 결정적 유한 오토마타 (DFA) (p. 83)

    * `lib/cs_compiler/dfa/demo.ex`

        DFA를 이용하여 만든 패리티 검사기, 식별자 토큰 인식기, 정수 토큰 인식기

* `lib/cs_compiler/cfg.ex`

    * Context-free grammar 정의

    * Nullable symbol 구하기 (p. 188)

    * `lib/cs_compiler/cfg/ll1.ex`

        * Ring sum 연산 (p. 272)
        * FIRST 및 FOLLOW 구하기 (p. 271, 273, 275~277)
        * LL(1) 조건 검사하기 (p. 278)

    * `lib/cs_compiler/cfg/predictive_parser.ex`

        * Predictive Parser 및 LL(1) 테이블 생성기 구현 (p. 289~300)
