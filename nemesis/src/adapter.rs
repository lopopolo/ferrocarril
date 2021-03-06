use mruby::convert::FromMrb;
use mruby::eval::MrbEval;
use mruby::sys;
use mruby::value::{Value, ValueLike};
use mruby::{Mrb, MrbError};
use std::rc::Rc;

use crate::request::Request;
use crate::response::Response;
use crate::Error;

pub type AppFactory = Box<dyn Fn(&Mrb) -> Result<RackApp, MrbError> + Send + Sync>;

pub struct RackApp {
    interp: Mrb,
    app: Value,
    name: String,
    mount_path: String,
}

impl RackApp {
    /// Create a Rack app by wrapping the supplied rackup source in a
    /// `Rack::Builder`. The returned [`Value`] has a call method and is
    /// suitable for serving a [`Mount`](crate::server::Mount).
    pub fn from_rackup(
        interp: &Mrb,
        builder_script: &str,
        name: &str,
        mount_path: &str,
    ) -> Result<Self, MrbError> {
        let builder = interp.eval("Rack::Builder")?;
        let app = builder.funcall::<Value, _, _>(
            "new_from_string",
            &[Value::from_mrb(interp, builder_script)],
        )?;
        app.protect();
        Ok(Self {
            interp: Rc::clone(interp),
            app,
            name: name.to_owned(),
            mount_path: mount_path.to_owned(),
        })
    }

    pub fn call<T: Request>(&self, req: &T) -> Result<Response, Error> {
        let env = req.to_env(&self.interp)?;
        let response = self.funcall::<Vec<Value>, _, _>("call", &[env])?;
        for value in &response {
            value.protect();
        }
        let response = Response::from_rack_tuple(&self.interp, response.as_slice())?;
        Ok(response)
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub fn mount_path(&self) -> &str {
        &self.mount_path
    }
}

impl ValueLike for RackApp {
    fn inner(&self) -> sys::mrb_value {
        self.app.inner()
    }

    fn interp(&self) -> &Mrb {
        &self.interp
    }
}
