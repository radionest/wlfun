import app_model
import app_update
import app_view
import lustre

pub fn main() {
  let app = lustre.application(app_model.init, app_update.update, app_view.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
