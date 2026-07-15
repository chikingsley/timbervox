import SwiftUI

struct HomeNotice: View {
  struct Content {
    let icon: String
    let title: String
    let message: String
  }

  let notice: Content

  var body: some View {
    SCAlert(icon: notice.icon, title: notice.title, description: notice.message)
  }
}
