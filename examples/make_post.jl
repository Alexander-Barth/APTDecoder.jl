
using ActivityPub
import JSON3

function publish(config,message,fnames; mime_type = "image/png")
   auth = config.activitypub
   conn = ActivityPub.Connection(auth.baseurl,auth.username,auth.password)
   #ActivityPub.verify_credentials(conn)
   
   media_ids = [ActivityPub.post_media(conn,fname,mime_type,
	                                    description = basename(fname)) for fname in fnames]
				  
   response = ActivityPub.post_status(conn,message, media_ids = media_ids)
   return nothing
end

