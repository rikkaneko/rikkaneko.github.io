---
title: Sticky Javascript
date: 2024-02-23 01:12:34
tags:
---
## Data types
There are **7** primitive types in Javascript: `string`, `number`, `bigint`, `boolean`, `symbol`, `null` and `undefined`, while `object` is special.  

|Data type|Internal represention|
|-|:-:|
|`string`|[UTF-16](https://en.wikipedia.org/wiki/UTF-16) characters|
|`number`|[IEEE-754](https://en.wikipedia.org/wiki/IEEE_754) 64-bit, equally `double` in C/C++|
|`bigint`|Integer in ±2<sup>53</sup>-1|
|`boolean`|`true`/`false`|
|`symbol`|Unique identifier created from `Symbol()`
|`null`|Empty or unknown value|
|`undefined`|Unassigned value|
|`object`|Keyed collections of various data|

🛈  `null` is used to represent absence of any object value, while `undefined` means "value is not assigned" and **should not** be used directly  
</br>
**Primitive** are copied by value.
```javascript
let a = "Hello, World!";
let b = a; // a and b are now independent.
```
`object` are copied "by reference".
```javascript
let a = {user: "Alice", money: 1000};
let b = a; // a and b share the reference of the same object.
```

🛈 `typeof(x)` can be used to find the type of argument `x`

## Integer-string conversion
#### String concatenation with binary +
If any of the operands is a string, then the other one is converted to string.
```javascript
"1" + 2 // "12"
1 + "2" // "12"
```
The first `+` sums two numbers, so it returns `4`, then the next `+` adds the string `"2"` to it.
```javascript
2 + 2 + "2" // "42" and not "221", from left to right
```

The first operand is a string, the compiler treats the other two operands as strings too. The 2 gets concatenated to '1'.
```javascript
"2" + 2 + 2 // "222" and not "24"
```
The binary `+` is the only operator that supports strings in such a way. Other arithmetic operators work only with numbers and always convert their operands to numbers.
```javascript
6 - "2" // 4, "2" is converted to number
"6" / "2" // 3, both "6" and "2" are converted to numbers
```

#### Numberic conversion with unary +
Unary `+` converts string to number
```javascript
+"1" // 1
+"-2" // -2
+true // 1
+"abc" // NaN, invalid number represention
```
⚠  `""`, `null` and `undefined` are special case in numberic conversion  

|Expression|Result|
|-|-|
|`+""`|`0`|
|`+null`|`0`|
|`+undefined`|`NaN`|

🛈  `NaN` represents an value that is undefined or unrepresentable, defined in [IEEE 754](https://en.wikipedia.org/wiki/IEEE_754)  

## Boolean conversion
Values that are "empty", like 0, an empty string, `null`, `undefined`, and `NaN`, become `false`, also called **falsy value**.  
Otherwise, is `true`, also called **truthy value**  
```javascript
Boolean("some") // true
Boolean("0") // true, non-empty string
```

## Comparison of different types
When comparing string to number, Javascript converts string to number
```javascript
"2" > 1 // 2 > 1, true
10 > "03" // 10 > 3, true
```

**The conditional logic in Javascript is just confused and erroneous.**  
</br>
Table 1: Truth Table
![Truth Table](../res/javascript-tf-table.jpg)

## OR operator ||
`||` operator finds the **first** truthy value, not just `true`/`false`.  
If all falsy value, return the last value.  
```javascript
false || true // true
false || false // false
let a = "" || false || "apple"; // "apple"
let b = null || "" // "", all falsy value, return the last value
```

## AND operator &&
`&&` operator finds the **first** falsy value, not just `true`/`false`.  
If all trusy value, return the last value.  
```javascript
false && true // false
true && false // false
let a = "apple" && null && "apple"; // null
let b = "apple" && 114154 // 114154, all trusy value, return the last value
```
Both `||` and `&&` have short-circuit evaluation. That is, these operators processes its arguments until the first truthy/falsy value is found, and then the value is returned immediately.  

## Double NOT operator !!
`!!` converts its operand to `boolean`.  

## Nullish coalescing operator ??
The result of `a ?? b`:  
If `a` defined, not `null` or `undefined`, then `a`.  
Otherwise, `b`.  
```javascript
// Example 1
let a; // undefined
a ?? "b" // "b"
```
⚠  `undefined` ≠ not defined variable, variable must be declared before use.  

</br>

*(More content is coming soon...)*  

## Optional chaining ?.

## Object to primitive conversion

## Backticks and formatted string

## Unicode characters in string: Surrogate pairs

## Array
#### Performance issues
#### Sorting

## Iterable

## Object as object key
Object only support `string`, `number` and `symbol` as key.

Use object as key becomes string key `[object Object]`, while `map` can use any type as key.  

## WeakMap/WeapSet

## Destructuring assignment, a.k.a structured binding

## Date

## Function
#### Normal function
```javascript
fucntion func(a, b) {
    return a + b
}
```
#### Arrow fcuntion
Arrow function does not have `this`.  
```javascript
let func = (a, b) => {
    return a + b;
}
```
Arrow function capture `this` as normal variable in the outer lexical environment. Different from normal function, 
arrow function does not have `this`, `arguments` and `super`.  
```javascript
let user = {
    name: "Alice",
    say
}
```
⚠  Arrow function cannot run with `new` since it does not have `this`.  

#### Lexical Environments
All functions remember the Lexical Environment in which they were made.   
A Hidden `[[Environment]]` property stores a reference to the Lexical Environment. This object hold all variable and a reference to outer enviroment
Such variables in `[[Environment]]` will become unavailable **in debugging**.

#### Closure

#### Unbounded this
🛈  Arrow function does not have its own `this`, reference from outer `this` instead.

#### Rest parameters and spread syntax, a.k.a parameter pack
Rest parameters (Variable arguments)
```javascript
function func(arg1, arg2, ...last) {
    for (let arg of last) { // last: Array
        // Handle of each arguments arg3, ..., argN
    }
}
```
⚠  The rest parameters must be at the end.  
🛈  A special array-like object `arguments` contains all arguments by their index for all function except arrow function.  

Spread syntax (Argument expansion)
```javascript
let args = ["apple", "pinapple", "orange"]
let a = func(...args); // Expand to func("apple", "pinapple", "orange");
// Spread syntax can appear at any position and mix with other normal values and other spread syntex.
let b = func(..args, "flower", ...args)
```
#### Function is object
Function is a normal callable object as same as other object.

#### Initial properties
|Argument||
|:-|-|
|`name`|Function name (get from assignement)|
|`length`|Number of arguments (Rest parameters are not counted)|

#### Function properties is not local variable

#### new Function syntax
Create function from string
```javascript
let func = new Function([arg1, arg2, ...argN], functionBody);
```
Function created using `new Function()` **does not** inherit the lexical environment but the global one. Therefore, such function cannot access to outer variables.  

#### Decoration and forwarding
Decorator is a wrapper around a function that alters its behavior.  
There are two built-in functions call function with `this = context` and forward the arguments.  
```javascript
func.call(context, arg1, arg2, ...)
```
```javascript
func.apply(context, args)
```
🛈  `apply()` accepts only array-like `args` while `call()` can pass arbitrary arguments.  
🛈  `apply()` tends to be faster in most of the cases due to internal optimization.  

#### Bind
`bind()` can be used to bind the function with `this = context` and set its arguments, resulting a callable object.
```javascript
bind(context, arg1, arg2, ...)
```
🛈  Set `context = null` if no `this`.  

## Old `var` syntax
`var` declarion 

## Object
#### Object Property Flags
Object value has three property flags,  
`writable`: if `true`, the value can be changed, otherwise it’s read-only.  
`enumerable`: if `true`, then listed in loops, otherwise not listed.  
`configurable`: if `true`, the property can be deleted and these attributes can be modified, otherwise not.  
🛈  Once a property is set `configurable: false`, all property flags cannot be changed again.  
The default property flags for new property is all `true`.  

#### Accessor property

#### Prototype
###### Old Way
`F.__proto__`

###### Modern way
`F.prototype`

## Global object
|Environment|Name|
|-|-|
|browser|`window`|
|Node.js|`global`|
|Standard|`globalThis`|
