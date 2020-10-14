(* This file was generated by Ocsigen Start.
   Feel free to use it, modify it, and redistribute it as you wish. *)

(* Notification demo *)

open%client Js_of_ocaml_lwt

(* Service for this demo *)
let%server service =
  Eliom_service.create
    ~path:(Eliom_service.Path ["demo-notif"])
    ~meth:(Eliom_service.Get Eliom_parameter.unit)
    ()

(* Make service available on the client *)
let%client service = ~%service

(* Name for demo menu *)
let%shared name () = [%i18n S.demo_notification]

(* Class for the page containing this demo (for internal use) *)
let%shared page_class = "os-page-demo-notif"

(* Instantiate function Os_notif.Simple for each kind of notification
   you need.
   The key is the resource ID. For example, if you are implementing a
   messaging application, it can be the chatroom ID
   (for example type key = int64).
*)
module Notif =
  Os_notif.Make_Simple (struct
    type key = unit (* The resources identifiers.
                       Here unit because we have only one resource. *)
    type notification = string
  end)

(* Broadcast message [v] *)
let%server notify v =
  (* Notify all client processes listening on this resource
     (identified by its key, given as first parameter)
     by sending them message v. *)
  Notif.notify (* ~notfor:`Me *) (() :  Notif.key) v;
  (* Use ~notfor:`Me to avoid receiving the message in this tab,
     or ~notfor:(`User myid) to avoid sending to the current user.
     (Where myid is Os_current_user.get_current_userid ())
  *)
  Lwt.return_unit

(* Make [notify] available client-side *)
let%client notify =
  ~%(Eliom_client.server_function [%json : string]
       (Os_session.connected_wrapper notify))

let%server listen = Notif.listen

let%client listen () =
  Lwt.async
    ~%(Eliom_client.server_function [%json : unit]
         (Os_session.connected_wrapper (fun () -> listen () ; Lwt.return_unit)))

(* Display a message every time the React event [e = Notif.client_ev ()]
   happens. *)
let%server () =
  Os_session.on_start_process (fun _ ->
    let e : (unit * string) Eliom_react.Down.t = Notif.client_ev () in
    ignore
      [%client
        (ignore @@
         React.E.map (fun (_, msg) ->
           (* Eliom_lib.alert "%s" msg *)
           Os_msg.msg ~level:`Msg (Printf.sprintf "%s" msg)
         ) ~%e
         : unit)];
    Lwt.return_unit)

(* Make a text input field that calls [f s] for each [s] submitted *)
let%shared make_form msg f =
  let inp = Eliom_content.Html.D.Raw.input ()
  and btn = Eliom_content.Html.(
    D.button ~a:[D.a_class ["button"]] [D.txt msg]
  ) in
  ignore [%client
    ((Lwt.async @@ fun () ->
      let btn = Eliom_content.Html.To_dom.of_element ~%btn
      and inp = Eliom_content.Html.To_dom.of_input ~%inp in
      Lwt_js_events.clicks btn @@ fun _ _ ->
      let v = Js_of_ocaml.Js.to_string inp##.value in
      let%lwt () = ~%f v in
      inp##.value := Js_of_ocaml.Js.string "";
      Lwt.return_unit)
     : unit)
  ];
  Eliom_content.Html.D.div [inp; btn]

let%server unlisten () = Notif.unlisten () ; Lwt.return_unit
let%client unlisten =
 ~%(Eliom_client.server_function [%json : unit]
      (Os_session.connected_wrapper unlisten))

(* Page for this demo *)
let%shared page () =
  (* Subscribe to notifications when entering this page: *)
  listen ();

  (* Unsubscribe from notifications when user leaves this page *)
  let _ : unit Eliom_client_value.t =
    [%client Eliom_client.Page_status.ondead (fun () -> Lwt.async unlisten)]
  in

  Lwt.return Eliom_content.Html.F.[
    h1 [%i18n demo_notification]
  ; p ([%i18n exchange_msg_between_users
          ~os_notif:[code [ txt "Os_notif" ] ]]
       @ [ br ()
         ; txt [%i18n S.open_multiple_tabs_browsers]
         ; br ()
         ; txt [%i18n S.fill_input_form_send_message]
         ])
  ; make_form [%i18n S.send_message] [%client (notify : string -> unit Lwt.t)]
  ]
