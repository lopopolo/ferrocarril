use std::error;
use std::fmt;

use crate::value::{types, Value};
use crate::Mrb;

mod array;
mod boolean;
mod bytes;
mod fixnum;
mod float;
mod hash;
mod nilable;
mod object;
mod string;

pub use self::array::*;
pub use self::boolean::*;
pub use self::bytes::*;
pub use self::fixnum::*;
pub use self::float::*;
pub use self::hash::*;
pub use self::nilable::*;
pub use self::object::*;
pub use self::string::*;

pub trait FromMrb<T> {
    type From;
    type To;

    fn from_mrb(interp: &Mrb, value: T) -> Self;
}

pub trait TryFromMrb<T>
where
    Self: Sized,
{
    type From;
    type To;

    unsafe fn try_from_mrb(interp: &Mrb, value: T) -> Result<Self, Error<Self::From, Self::To>>;
}

/// Provide a falible converter for types that implement an infallible
/// conversion.
impl<From, To> TryFromMrb<From> for To
where
    To: FromMrb<From>,
{
    type From = <Self as FromMrb<From>>::From;
    type To = <Self as FromMrb<From>>::To;

    unsafe fn try_from_mrb(interp: &Mrb, value: From) -> Result<Self, Error<Self::From, Self::To>> {
        Ok(FromMrb::from_mrb(interp, value))
    }
}

#[derive(Clone, Eq, PartialEq)]
pub struct Error<From, To> {
    from: From,
    to: To,
}

impl<From, To> fmt::Display for Error<From, To>
where
    From: fmt::Display,
    To: fmt::Display,
{
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "failed to convert from {} to {}", self.from, self.to)
    }
}

impl<From, To> fmt::Debug for Error<From, To>
where
    From: fmt::Display,
    To: fmt::Display,
{
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "mruby conversion error: {}", self)
    }
}

impl<To, From> error::Error for Error<To, From>
where
    From: fmt::Display,
    To: fmt::Display,
{
    fn description(&self) -> &str {
        "Failed to convert types between ruby and rust"
    }

    fn cause(&self) -> Option<&dyn error::Error> {
        None
    }
}

// This converter implementation is for Ruby functions that return void.
impl FromMrb<Value> for () {
    type From = types::Ruby;
    type To = types::Rust;

    fn from_mrb(_interp: &Mrb, _value: Value) -> Self {}
}

#[cfg(test)]
mod tests {
    use crate::convert::Error;
    use crate::value::types::*;

    #[test]
    fn ruby_to_rust_error_display() {
        let err = Error {
            from: Ruby::Fixnum,
            to: Rust::Vec,
        };
        assert_eq!(
            format!("{}", err),
            "failed to convert from ruby Fixnum to rust Vec"
        );
    }

    #[test]
    fn ruby_to_rust_error_debug() {
        let err = Error {
            from: Ruby::Fixnum,
            to: Rust::Vec,
        };
        assert_eq!(
            format!("{:?}", err),
            "mruby conversion error: failed to convert from ruby Fixnum to rust Vec"
        );
    }

    #[test]
    fn rust_to_ruby_error_display() {
        let err = Error {
            from: Rust::Bool,
            to: Ruby::String,
        };
        assert_eq!(
            format!("{}", err),
            "failed to convert from rust bool to ruby String"
        );
    }

    #[test]
    fn rust_to_ruby_error_debug() {
        let err = Error {
            from: Rust::Bool,
            to: Ruby::String,
        };
        assert_eq!(
            format!("{:?}", err),
            "mruby conversion error: failed to convert from rust bool to ruby String"
        );
    }
}
