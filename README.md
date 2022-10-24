# N-back

A simple N-back task writen in Matlab with psychtoolbox.

## Usage

Basically, there are four types of practice and 1 run for test.

* Digit n-back

```matlab
% practice digit 0-back
exp.start("dig", "prac0");
% practice digit 1-back
exp.start("dig", "prac1");
% practice digit 2-back
exp.start("dig", "prac2");
% practice digit n-back combined
exp.start("dig", "prac");
% test digit n-back with given id
exp.start("dig", "test", "id", 1);
```

* Location n-back

```matlab
% practice location 0-back
exp.start("loc", "prac0");
% practice location 1-back
exp.start("loc", "prac1");
% practice location 2-back
exp.start("loc", "prac2");
% practice location n-back combined
exp.start("loc", "prac");
% test location n-back with given id
exp.start("loc", "test", "id", 1);
```
