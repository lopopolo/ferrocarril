use mruby::def::EnclosingRubyScope;
use mruby::file::MrbFile;
use mruby::load::MrbLoadSources;
use mruby::Mrb;
use mruby::MrbError;
use mruby_gems::Gem;
use std::borrow::Cow;
use std::convert::AsRef;

pub fn init(interp: &Mrb) -> Result<(), MrbError> {
    Nemesis::init(interp)
}

#[derive(RustEmbed)]
#[folder = "$CARGO_MANIFEST_DIR/ruby/lib"]
struct Nemesis;

impl Nemesis {
    fn contents<T: AsRef<str>>(path: T) -> Result<Vec<u8>, MrbError> {
        let path = path.as_ref();
        Self::get(path)
            .map(Cow::into_owned)
            .ok_or_else(|| MrbError::SourceNotFound(path.to_owned()))
    }
}

impl MrbFile for Nemesis {
    fn require(interp: Mrb) -> Result<(), MrbError> {
        interp.borrow_mut().def_module::<Self>("Nemesis", None);
        Ok(())
    }
}

impl Gem for Nemesis {
    fn init(interp: &Mrb) -> Result<(), MrbError> {
        for source in Self::iter() {
            let contents = Self::contents(&source)?;
            interp.def_rb_source_file(source, contents)?;
        }
        interp.def_file_for_type::<_, Self>("nemesis.rb")?;
        interp.def_file_for_type::<_, Response>("nemesis/response.rb")?;
        Ok(())
    }
}

pub struct Response;

impl MrbFile for Response {
    fn require(interp: Mrb) -> Result<(), MrbError> {
        let scope = interp
            .borrow()
            .module_spec::<Nemesis>()
            .map(EnclosingRubyScope::module)
            .ok_or_else(|| MrbError::NotDefined("Nemesis".to_owned()))?;
        interp
            .borrow_mut()
            .def_class::<Self>("Response", Some(scope), None);
        Ok(())
    }
}
